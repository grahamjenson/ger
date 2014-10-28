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
  constructor: (@knex, @schema = 'public') ->

  drop_tables: ->
    drop_tables(@knex,@schema)

  init_tables: ->
    init_tables(@knex,@schema)

  add_event: (person, action, thing, dates = {}) ->
    expires_at = dates.expires_at
    created_at = dates.created_at || new Date().toISOString()
    @add_event_to_db(person, action, thing, created_at, expires_at)

  questions_marks_to_dollar: (query) ->
    counter = 1
    nquery = ""
    for i in [0...query.length]
      char = query[i]
      if char == '?'
        char = "$#{counter}"
        counter +=1 
      nquery += char
    nquery

  upsert: (table, insert_attr, identity_attr, update_attr) ->
    bindings = []

    update = "update #{table} set "
    update += ("\"#{k}\" = ?" for k,v of update_attr).join(', ')
    bindings = bindings.concat((v for k, v of update_attr))

    update += " where "
    update += ("\"#{k}\" = ?" for k,v of identity_attr).join(' and ')
    bindings = bindings.concat((v for k, v of identity_attr))

    
    insert  = "insert into #{table} ("
    insert += ("\"#{k}\"" for k,v of insert_attr).join(', ')
    insert += ") select "
    insert  += ("?" for k,v of insert_attr).join(', ')
    bindings = bindings.concat((v for k, v of insert_attr))

    query = "WITH upsert AS (#{update} RETURNING *) #{insert} WHERE NOT EXISTS (SELECT * FROM upsert);"

    #defined here http://www.the-art-of-web.com/sql/upsert/

    #replace the ? with $1 variables
    query = @questions_marks_to_dollar(query)

    @knex.client.acquireConnection()
    .then( (connection) =>
      deferred = bb.defer()
      connection.query("BEGIN; LOCK TABLE #{table} IN SHARE ROW EXCLUSIVE MODE;", (err) -> deferred.reject(err) if err);
      connection.query(query, bindings, (err) -> deferred.reject(err) if err);
      connection.query('COMMIT;', (err) ->
        if err
          deferred.reject(err)
        else
          deferred.resolve()
      )
      deferred.promise.finally( => @knex.client.releaseConnection(connection))
    )


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
    

  person_thing_query: (limit)->
    @knex("#{@schema}.events")
    .select('person', 'thing').max('created_at as max_ca')
    .groupBy('person','thing')
    .orderByRaw('max_ca DESC')
    .limit(limit)


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

  get_things_that_actioned_person: (person, action, limit = 100) =>
    @person_thing_query(limit)
    .where(person: person, action: action)
    .then( (rows) ->
      (r.thing for r in rows)
    )

  last_1000_events: (person) ->
    @knex("#{@schema}.events")
    .select("person", "action", "thing")
    .where(person: person)
    .orderByRaw('created_at DESC')
    .limit(1000)

  get_related_people: (person, actions, action, limit = 100) ->
    return bb.try(-> []) if !actions or actions.length == 0
    one_degree_similar_people = @knex(@last_1000_events(person).as('e'))
    .innerJoin("#{@schema}.events as f", -> @on('e.thing', 'f.thing').on('e.action','f.action').on('f.person','!=', 'e.person'))
    .where('e.person', person)
    .whereIn('f.action', actions)
    .select('f.person')
    .groupBy('f.person').max('f.created_at')
    .orderByRaw('max(f.created_at) DESC')

    filter_people = @knex("#{@schema}.events")
    .select("person")
    .where(action: action)
    .whereRaw("person = x.person")

    @knex(one_degree_similar_people.as('x'))
    .whereExists(filter_people)
    .limit(limit)
    .then( (rows) ->
      (r.person for r in rows)
    )

  filter_things_by_previous_actions: (person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0

    bindings = []
    values = []
    for t in things
      values.push "(?)"
      bindings.push t

    things_rows = "(VALUES #{values.join(", ")} ) AS t (tthing)"

    filter_things_sql = @knex("#{@schema}.events")
    .select("thing")
    .where(person: person)
    .whereIn('action', actions)
    .whereRaw("thing = t.tthing")
    .toSQL()

    bindings = bindings.concat(filter_things_sql.bindings)
   
    query = "select tthing from #{things_rows} where not exists (#{filter_things_sql.sql})"
    query = @questions_marks_to_dollar(query)
    @knex.raw(query, bindings)
    .then( (rows) ->
      (r.tthing for r in rows.rows)
    )

  things_people_have_actioned: (action, people, limit = 100) ->
    return bb.try(->[]) if people.length == 0
    @person_thing_query(limit)
    .where(action: action)
    .whereIn('person', people)
    .then( (rows) ->
      temp = {}
      for r in rows
        temp[r.person] = [] if temp[r.person] == undefined
        temp[r.person].push r.thing
      temp
    )

  last_1000_things_for_action: (action_binding) ->
    @knex("#{@schema}.events")
    .select('thing')
    .groupBy('thing')
    .orderByRaw("max(created_at) DESC")
    .whereRaw("action = #{action_binding}")
    .limit(1000)

  get_query_for_jaccard_distances_between_people_for_action: (person_binding, action_binding, action_i) ->
    s1 = @last_1000_things_for_action(action_binding).whereRaw("person = #{person_binding}").toString()
    s2 = @last_1000_things_for_action(action_binding).whereRaw('person = cperson').toString()

    intersection = @knex.raw("(select count(*) from ((#{s1}) INTERSECT (#{s2})) as inter)::float").toString()
    # case statement is needed for divide by zero problem
    union = @knex.raw("(select (case count(*) when 0 then 1 else count(*) end) from ((#{s1}) UNION (#{s2})) as uni)::float").toString()
    
    # dont put the name of the action in the sql stopping sql injection
    "(#{intersection} / #{union}) as action_#{action_i}"


  get_jaccard_distances_between_people: (person, people, actions) ->
    return bb.try(->[]) if people.length == 0

    bindings = [person]
    action_diff = bindings.length + 1
    bindings = bindings.concat(actions)
    people_diff = bindings.length + 1
    bindings = bindings.concat(people)

    #TODO SQL INJECTION
    v_people = ("($#{people_diff + i})" for p,i in people)

    distances = []
    for action, i in actions
      distances.push @get_query_for_jaccard_distances_between_people_for_action("$1", "$#{action_diff + i}", i)

    query = "select cperson , #{distances.join(',')} from (VALUES #{v_people} ) AS t (cperson)"
    @knex.raw(query, bindings)
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


  remove_non_unique_events_for_people: (people) ->
    return bb.try( -> []) if people.length == 0
    promises = (@remove_non_unique_events_for_person(person) for person in people)
    bb.all(promises)

  remove_non_unique_events_for_person: (person) ->
    # TODO I would suggest doing it for active people. THIS IS WAY TOO SLOW!!!
    # http://stackoverflow.com/questions/1746213/how-to-delete-duplicate-entries
    bindings = [person]
    query = "DELETE FROM #{@schema}.events e1 
    USING #{@schema}.events e2 
    WHERE e1.person = $1 AND e1.expires_at is NULL AND e1.id <> e2.id AND e1.person = e2.person AND e1.action = e2.action AND e1.thing = e2.thing AND 
    (e1.created_at < e2.created_at OR (e1.created_at = e2.created_at AND e1.id < e2.id) )" #LEXICOGRAPHIC ORDERING for created at then id
    @knex.raw(query, bindings)

  vacuum_analyze: ->
    @knex.raw("VACUUM ANALYZE #{@schema}.events")

  get_active_people: ->
    #select most_common_vals from pg_stats where attname = 'person';
    @knex('pg_stats').select('most_common_vals').where(attname: 'person', tablename: 'events', schemaname: @schema)
    .then((rows) ->
      return [] if not rows[0]
      common_str = rows[0].most_common_vals
      return [] if not common_str
      common_str = common_str[1..common_str.length-2]
      people = common_str.split(',')
      people
    )

  truncate_people_per_action: (people, trunc_size) ->
    return bb.try( -> []) if people.length == 0  
    @get_ordered_action_set_with_weights()
    .then((action_weights) =>
      return [] if action_weights.length == 0
      actions = (aw.key for aw in action_weights)
      #cut each action down to size
      promises = (@truncate_people_actions(person, trunc_size, action) for person in people for action in actions)

      bb.all(promises)
    )
    

  truncate_people_actions: (person, trunc_size, action) ->
    bindings = [person, action]

    q = "delete from events as e 
         where e.id in 
         (select id from events where action = $2 and person = $1 and expires_at is NULL
         order by created_at DESC offset #{trunc_size});"
    
    knex.raw(q ,bindings)
    .then( (rows) ->
    )
    
  remove_events_till_size: (number_of_events) ->
    #TODO move too offset method
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
