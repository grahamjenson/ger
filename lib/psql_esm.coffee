bb = require 'bluebird'
fs = require 'fs'
split = require 'split'
pg = require('pg');
copyFrom = require('pg-copy-streams').from;


unique_rows = (rows, row) ->
  unique = {}
  (unique[r[row]] = r[row] for r in rows)
  Object.keys(unique)

get_list_to_size = (fn, i, list, size) =>
  #recursive promise that will resolve till either the end
  if list.length > size
    return bb.try(-> list)
  fn(i)
  .then( (new_list) =>
    return bb.try(-> list) if new_list == null 
    new_list = list.concat new_list
    i = i + 1
    get_list_to_size(fn, i, new_list, size)
  )

Transform = require('stream').Transform;
class CounterStream extends Transform
  _transform: (chunk, encoding, done) ->
    @count |= 0
    if chunk.toString().trim() != ''
      @count += 1
    @push(chunk)
    done()


init_events_table = (knex, schema) ->
  knex.schema.createTable("#{schema}.events",(table) ->
    table.increments();
    table.string('person').index().notNullable()
    table.string('action').index().notNullable()
    table.string('thing').index().notNullable()
    table.timestamp('created_at').notNullable()
    table.timestamp('expires_at')
  )
  

init_action_table = (knex, schema) ->
  knex.schema.createTable("#{schema}.actions",(table) ->
    table.increments();
    table.string('action').unique().index().notNullable()
    table.integer('weight').notNullable()
    table.timestamp('created_at').notNullable()
    table.timestamp('updated_at').notNullable()
  )

#CLASS ACTIONS
drop_tables = (knex, schema = 'public') ->
  bb.all( [
    knex.schema.dropTableIfExists("#{schema}.events"),
    knex.schema.dropTableIfExists("#{schema}.actions")
  ])
  .then( -> knex.schema.raw("DROP SCHEMA IF EXISTS #{schema}"))
  
init_tables = (knex, schema = 'public') ->
  knex.schema.raw("CREATE SCHEMA IF NOT EXISTS #{schema}")
  .then( => bb.all([init_events_table(knex, schema), init_action_table(knex, schema)]))

class EventStoreMapper
  
  #INSTANCE ACTIONS
  constructor: (@knex, @schema = 'public', limits = {}) ->
    @similar_objects_limit = limits.similar_objects_limit || 100
    @things_limit = limits.things_limit  || 100
    @people_limit = limits.people_limit || 100
    @upper_limit = limits.upper_limit || 10000

  drop_tables: ->
    drop_tables(@knex,@schema)

  init_tables: ->
    init_tables(@knex,@schema)

  add_event: (person, action, thing, expires_at = null) ->
    @add_event_to_db(person, action, thing, expires_at)

  upsert: (table, insert_attr, identity_attr, update_attr) ->
    insert = @knex(table).insert(insert_attr).toString()
    #bug described here http://stackoverflow.com/questions/15840922/where-not-exists-in-postgresql-gives-syntax-error
    insert = insert.replace(/\svalues\s\(/, " select ")[..-2]

    update = @knex(table).where(identity_attr).update(update_attr).toString()

    #defined here http://www.the-art-of-web.com/sql/upsert/
    query = "BEGIN; LOCK TABLE #{table} IN SHARE ROW EXCLUSIVE MODE; WITH upsert AS (#{update} RETURNING *) #{insert} WHERE NOT EXISTS (SELECT * FROM upsert); COMMIT;"
    @knex.raw(query)

  find_event: (person, action, thing) ->
    @knex("#{@schema}.events")
    .select("person", "action", "thing", "created_at", "expires_at")
    .where(person: person, action: action, thing: thing)
    .limit(1)
    .then((rows)->
      if rows.length > 0
        return rows[0]
      else
        return null
    )

  add_event_to_db: (person, action, thing, expires_at = null) ->
    now = new Date().toISOString()
    insert_attr = {person: person, action: action, thing: thing, created_at: now, expires_at: expires_at}
    identity_attr = {person: person, action: action, thing: thing}
    update_attr = {created_at: now, expires_at: expires_at}
    @upsert("#{@schema}.events", insert_attr, identity_attr, update_attr)

  set_action_weight: (action, weight, overwrite = true) ->
    now = new Date().toISOString()
    insert_attr =  {action: action, weight: weight, created_at: now, updated_at: now}

    identity_attr = {action: action}
    update_attr = {action: action, updated_at: now}
    update_attr["weight"] = weight if overwrite
    @upsert("#{@schema}.actions", insert_attr, identity_attr, update_attr)
    

  
  events_for_people_action_things: (people, action, things) ->
    return bb.try(->[]) if people.length == 0 || things.length == 0

    @knex("#{@schema}.events").where(action: action).whereIn('person', people).whereIn('thing', things).limit(@upper_limit)

  has_person_actioned_thing: (person, action, thing) ->
    @has_event(person,action,thing)

  get_actions_of_person_thing_with_weights: (person, thing) ->
    @knex("#{@schema}.events")
    .select("#{@schema}.events.action as key", "#{@schema}.actions.weight")
    .leftJoin("#{@schema}.actions", "#{@schema}.events.action", "#{@schema}.actions.action")
    .where(person: person, thing: thing)
    .orderBy('weight', 'desc')
    .limit(@upper_limit)

  get_ordered_action_set_with_weights: ->
    @knex("#{@schema}.actions")
    .select('action as key', 'weight')
    .orderBy('weight', 'desc')

    
  get_action_weight: (action) ->
    @knex("#{@schema}.actions").select('weight').where(action: action)
    .then((rows)->
      if rows.length > 0
        return parseInt(rows[0].weight)
      else
        return null
    )

  get_things_that_actioned_people: (people, action) =>
    return bb.try(->[]) if people.length == 0
    @knex("#{@schema}.events")
    .select('thing', 'created_at')
    .where(action: action)
    .whereIn('person', people)
    .orderBy('created_at', 'desc')
    .limit(@upper_limit)
    .then( (rows) ->
      #Do not make distinct -- Graham
      (r.thing for r in rows)
    )

  get_people_that_actioned_things: (things, action) =>
    return bb.try(->[]) if things.length == 0
    @knex("#{@schema}.events")
    .select('person', 'created_at')
    .where(action: action)
    .whereIn('thing', things)
    .orderBy('created_at', 'desc')
    .limit(@upper_limit)
    .then( (rows) ->
      #Do not make distinct -- Graham
      (r.person for r in rows)
    )

  get_things_that_actioned_person: (person, action) =>
    @knex("#{@schema}.events")
    .select('thing', 'created_at')
    .where(person: person, action: action)
    .orderBy('created_at', 'desc')
    .limit(@things_limit)
    .then( (rows) ->
      unique_rows(rows, 'thing')
    )

  get_people_that_actioned_thing: (thing, action) =>
    @knex("#{@schema}.events")
    .select('person', 'created_at')
    .where(thing: thing, action: action)
    .orderBy('created_at', 'desc')
    .limit(@people_limit)
    .then( (rows) ->
      unique_rows(rows, 'person')
    )

  things_people_have_actioned: (action, people) ->
    @knex("#{@schema}.events").select('thing', 'created_at')
    .where(action: action)
    .whereIn('person', people)
    .orderBy('created_at', 'desc')
    .limit(@things_limit)
    .then( (rows) ->
      unique_rows(rows, 'thing')
    )

  things_jaccard_metric: (thing1, thing2, action) ->
    q1 = @knex("#{@schema}.events").select('person').distinct().where(thing: thing1, action: action).toString()
    q2 = @knex("#{@schema}.events").select('person').distinct().where(thing: thing2, action: action).toString()

    intersection = @knex.raw("#{q1} INTERSECT #{q2}")
    union = @knex.raw("#{q1} UNION #{q2}")
    bb.all([intersection, union])
    .spread((int_count, uni_count) ->
      ret = int_count.rowCount / uni_count.rowCount
      if isNaN(ret)
        return 0
      return ret
    )

  people_jaccard_metric: (person1, person2, action) ->
    q1 = @knex("#{@schema}.events").select('thing').distinct().where(person: person1, action: action).toString()
    q2 = @knex("#{@schema}.events").select('thing').distinct().where(person: person2, action: action).toString()

    intersection = @knex.raw("#{q1} INTERSECT #{q2}")
    union = @knex.raw("#{q1} UNION #{q2}")
    bb.all([intersection, union])
    .spread((int_count, uni_count) ->
      ret = int_count.rowCount / uni_count.rowCount
      if isNaN(ret)
        return 0
      return ret
    )


  #knex wrapper functions
  has_event: (person, action, thing) ->
    @knex("#{@schema}.events").where({person: person, action: action, thing: thing})
    .then( (rows) ->
      rows.length > 0
    )

  has_action: (action) ->
    @knex("#{@schema}.actions").where(action: action)
    .then( (rows) ->
      rows.length > 0
    )

  count_events: ->
    @knex("#{@schema}.events").count()
    .then (count) -> parseInt(count[0].count)

  count_actions: ->
    @knex("#{@schema}.actions").count()
    .then (count) -> parseInt(count[0].count)

  bootstrap: (stream) ->
    #stream of  person,action,thing,date CSV
    #this will require manually adding the actions

    runner = new @knex.client.Runner(@knex.client)
    runner.ensureConnection()
    .then( (connection) =>
      runner.connection = connection
      deferred = bb.defer()
      pg_stream = runner.connection.query(copyFrom("COPY #{@schema}.events (person, action, thing, created_at) FROM STDIN CSV"));
      
      counter = new CounterStream()
      stream.pipe(split(/^/gm)).pipe(counter).pipe(pg_stream)
      .on('end', -> deferred.resolve(counter.count))
      .on('error', (error) -> deferred.reject(error))
      
      deferred.promise
    )
    .finally( -> runner.cleanupConnection())
    
  # DATABASE CLEANING METHODS

  remove_expired_events: ->
    #removes the events passed their expiry date
    now = new Date().toISOString()
    @knex("#{@schema}.events").where('expires_at', '<', now).del()

  remove_non_unique_events: ->
    #remove all events that are not unique
    # http://stackoverflow.com/questions/1746213/how-to-delete-duplicate-entries
    query = "DELETE FROM #{@schema}.events e1 
    USING #{@schema}.events e2 
    WHERE e1.person = e2.person AND e1.action = e2.action AND e1.thing = e2.thing AND 
    (e1.created_at < e2.created_at OR (e1.created_at = e2.created_at AND e1.id < e2.id) )" #LEXICOGRAPHIC ORDERING for created at then id
    @knex.raw(query)

  remove_superseded_events: ->
    #Remove events that have been superseded events, e.g. bob views a and bob redeems a, we can remove bob views a
    bb.try(-> true)

  remove_excessive_user_events: ->
    #find members with most events and truncate them down
    bb.try(-> true)
    
  remove_events_till_size: (number_of_events) ->
    #removes old events till there is only number_of_events left
    query = "delete from #{@schema}.events where id not in (select id from #{@schema}.events order by created_at desc limit #{number_of_events})"
    @knex.raw(query)

EventStoreMapper.drop_tables = drop_tables
EventStoreMapper.init_tables = init_tables

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return EventStoreMapper)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = EventStoreMapper;
