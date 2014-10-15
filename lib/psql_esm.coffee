bb = require 'bluebird'
fs = require 'fs'
pg = require('pg');
copyFrom = require('pg-copy-streams').from;


Transform = require('stream').Transform;
class CounterStream extends Transform
  _transform: (chunk, encoding, done) ->
    @count |= 0
    for ch in chunk
      @count += 1 if ch == 10
    @push(chunk)
    done()


init_events_table = (knex, schema) ->
  knex.schema.createTable("#{schema}.events",(table) ->
    table.increments();
    table.string('person').notNullable().index()
    table.string('action').notNullable()
    table.string('thing').notNullable().index()
    table.timestamp('created_at').notNullable().index()
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
    @upper_limit = limits.upper_limit || 1000

  drop_tables: ->
    drop_tables(@knex,@schema)

  init_tables: ->
    init_tables(@knex,@schema)

  add_event: (person, action, thing, dates = {}) ->
    expires_at = dates.expires_at
    created_at = dates.created_at || new Date().toISOString()
    @add_event_to_db(person, action, thing, created_at, expires_at)

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

  add_event_to_db: (person, action, thing, created_at, expires_at = null) ->
    insert_attr = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
    identity_attr = {person: person, action: action, thing: thing}
    update_attr = {created_at: created_at, expires_at: expires_at}
    @upsert("#{@schema}.events", insert_attr, identity_attr, update_attr)

  set_action_weight: (action, weight, overwrite = true) ->
    now = new Date().toISOString()
    insert_attr =  {action: action, weight: weight, created_at: now, updated_at: now}

    identity_attr = {action: action}
    update_attr = {action: action, updated_at: now}
    update_attr["weight"] = weight if overwrite
    @upsert("#{@schema}.actions", insert_attr, identity_attr, update_attr)
    

  person_thing_query: ->
    @knex("#{@schema}.events")
    .select('person', 'thing').max('created_at')
    .groupBy('person','thing')
    .orderByRaw('MAX(created_at) DESC')
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

  get_people_that_actioned_things: (things, action) =>
    return bb.try(->[]) if things.length == 0
    @person_thing_query()
    .where(action: action)
    .whereIn('thing', things)
    .then( (rows) ->
      #Need to make distinct for person, action, thing
      (r.person for r in rows)
    )

  get_things_that_actioned_person: (person, action) =>
    @person_thing_query()
    .where(person: person, action: action)
    .limit(@things_limit)
    .then( (rows) ->
      (r.thing for r in rows)
    )

  things_people_have_actioned: (action, people) ->
    @person_thing_query()
    .where(action: action)
    .whereIn('person', people)
    .then( (rows) ->
      temp = {}
      for r in rows
        temp[r.person] = [] if temp[r.person] == undefined
        temp[r.person].push r.thing
      temp
    )

  get_recent_people_for_action: (action, limit = @people_limit) ->
    q = @knex("#{@schema}.events")
    .select('person')
    .orderByRaw('created_at DESC')
    .limit(limit)
    .where(action: action).toString()

    @knex.raw(q)
    .then( (rows) ->
      (row.person for row in rows.rows)
    )

  get_query_for_jaccard_distances_between_people_for_action: (person, action, action_i) ->
    s1 = @knex("#{@schema}.events").select('thing').groupBy('thing').where(person: person, action: action).orderByRaw('MAX(created_at) DESC').toString()
    s2 = @knex("#{@schema}.events").select('thing').groupBy('thing').whereRaw('person = cperson').where(action: action).orderByRaw('MAX(created_at) DESC').toString()

    intersection = @knex.raw("(select count(*) from ((#{s1}) INTERSECT (#{s2})) as inter)::float").toString()
    # case statement is needed for divide by zero problem
    union = @knex.raw("(select (case count(*) when 0 then 1 else count(*) end) from ((#{s1}) UNION (#{s2})) as uni)::float").toString()
    
    # dont put the name of the action in the sql stopping sql injection
    "(#{intersection} / #{union}) as action_#{action_i}"


  get_jaccard_distances_between_people: (person, people, actions) ->
    return bb.try(->[]) if people.length == 0
    v_people = ("('#{p}')" for p in people)
    distances = []
    for action, i in actions
      distances.push @get_query_for_jaccard_distances_between_people_for_action(person, action, i,)

    @knex.raw("select cperson , #{distances.join(',')} from (VALUES #{v_people} ) AS t (cperson)")
    .then( (rows) ->
      temp = {}
      for row in rows.rows
        temp[row.cperson] = {}
        for action, i in actions
          temp[row.cperson][action] = row["action_#{i}"]
      temp
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
    #stream of  person, action, thing, created_at, expires_at CSV
    #this will require manually adding the actions
    @knex.client.acquireConnection()
    .then( (connection) =>
      deferred = bb.defer()
      pg_stream = connection.query(copyFrom("COPY #{@schema}.events (person, action, thing, created_at, expires_at) FROM STDIN CSV"));
      counter = new CounterStream()
      stream.pipe(counter).pipe(pg_stream)
      .on('end', -> deferred.resolve(counter.count))
      .on('error', (error) -> deferred.reject(error))
      deferred.promise.finally( => @knex.client.releaseConnection(connection))
    )



    
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
    WHERE e1.id <> e2.id AND e1.person = e2.person AND e1.action = e2.action AND e1.thing = e2.thing AND 
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
