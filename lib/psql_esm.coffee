bb = require 'bluebird'
fs = require 'fs'
pg = require('pg');
copyFrom = require('pg-copy-streams').from;
_ = require 'underscore'

Errors = require './errors'

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
    table.string('person').notNullable()
    table.string('action').notNullable()
    table.string('thing').notNullable()
    table.timestamp('created_at').notNullable()
    table.timestamp('expires_at')

  ).then( ->
    i1 = knex.raw("create index idx_person_created_at_#{schema}_events on \"#{schema}\".events (person, action, created_at DESC)")
    i2 = knex.raw("create index idx_thing_created_at_#{schema}_events on \"#{schema}\".events (thing, action, created_at DESC)")
    bb.all([i1,i2])
  )

#CLASS ACTIONS
drop_tables = (knex, schema = 'public') ->
  knex.schema.dropTableIfExists("#{schema}.events")
  .then( -> knex.schema.raw("DROP SCHEMA IF EXISTS \"#{schema}\""))
  
init_tables = (knex, schema = 'public') ->
  knex.schema.raw("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")
  .then( => init_events_table(knex, schema))


#The only stateful thing in this ESM is the UUID (schema), it should not be changed

class PSQLEventStoreManager
  
  #INSTANCE ACTIONS
  constructor: (options = {}) ->
    @_knex = options.knex

  destroy: (namespace) ->
    drop_tables(@_knex, namespace)

  initialize: (namespace) ->
    @exists(namespace)
    .then( (exists) =>
      if !exists
        init_tables(@_knex, namespace)
    )

  exists: (namespace) ->
    @_knex.raw("SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{namespace}'")
    .then((result) =>
      result.rows.length >= 1
    )

  add_events: (events) ->
    namespaces = {}
    for e in events
      e.created_at = e.created_at || new Date().toISOString()
      namespaces[e.namespace] = [] if not namespaces[e.namespace]
      namespaces[e.namespace].push e
      delete e.namespace

    promises = []
    for namespace, es of namespaces
      promises.push @add_events_to_namespace(namespace, es)

    bb.all(promises)

    
  add_event: (namespace, person, action, thing, dates = {}) ->
    @add_events([{
      namespace: namespace
      person: person
      action: action
      thing: thing
      created_at: dates.created_at
      expires_at: dates.expires_at
    }])

  add_events_to_namespace: (namespace, events) ->
    @_knex("#{namespace}.events").insert(events)
    .catch( (error) ->
      console.log error.message
      if error.message.indexOf("relation") > -1 and error.message.indexOf(namespace) > -1 and error.message.indexOf("does not exist") > -1
        throw new Errors.NamespaceDoestNotExist()
    )

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

    @_knex.client.acquireConnection()
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
      deferred.promise.finally( => @_knex.client.releaseConnection(connection))
    )

  _event_selection: (namespace, person, action, thing) ->
    q = @_knex("#{namespace}.events")
    .select("person", "action", "thing", "created_at", "expires_at")
    .orderBy('created_at', 'desc')

    q = q.where(person: person) if person
    q = q.where(action: action) if action
    q = q.where(thing: thing) if thing

    return q

  find_events: (namespace, person, action, thing, options = {}) ->
    options = _.defaults(options, {size: 50, page: 0})
    size = options.size
    page = options.page
    
    @_event_selection(namespace, person, action, thing)
    .limit(size)
    .offset(size*page)
    .then((rows)->
      rows
    )

  delete_events: (namespace, person, action, thing) ->
    @_event_selection(namespace, person, action, thing)
    .del()
    .then((delete_count)->
      {deleted: delete_count}
    )


  add_event_to_db: (namespace, person, action, thing, created_at, expires_at = null) ->
    insert_attr = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
    identity_attr = {person: person, action: action, thing: thing}
    update_attr = {created_at: created_at, expires_at: expires_at}
    @upsert("\"#{namespace}\".events", insert_attr, identity_attr, update_attr)


  person_history_count: (namespace, person) ->
    @_knex("#{namespace}.events")
    .groupBy('thing')
    .where({person: person})
    .count()
    .then( (counts) ->
      counts.length
    )

  last_events: (namespace, person, limit) ->
    @_knex("#{namespace}.events")
    .select("person", "action", "thing", "created_at")
    .where(person: person)
    .orderByRaw('created_at DESC')
    .limit(limit)

  find_similar_people: (namespace, person, actions, action, limit = 100, search_limit = 500) ->
    return bb.try(-> []) if !actions or actions.length == 0

    one_degree_similar_people = @_knex(@last_events(namespace, person, search_limit ).as('e'))
    .innerJoin("#{namespace}.events as f", -> @on('e.thing', 'f.thing').on('e.action','f.action').on('f.person','!=', 'e.person'))
    .where('e.person', person)
    .whereIn('f.action', actions)
    .select(@_knex.raw("f.person, date_trunc('day', max(e.created_at)) as created_at_day, count(f.person) as count"))
    .groupBy('f.person')
    .orderByRaw("created_at_day DESC, count(f.person) DESC")

    filter_people = @_knex("#{namespace}.events")
    .select("person")
    .where(action: action)
    .whereRaw("person = x.person")

    @_knex(one_degree_similar_people.as('x'))
    .select('x.person', 'x.created_at_day', 'x.count')
    .whereExists(filter_people)
    .orderByRaw("x.created_at_day DESC, x.count DESC")
    .limit(limit)
    .then( (rows) ->
      (r.person for r in rows)
    )

  filter_things_by_previous_actions: (namespace, person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0

    bindings = []
    values = []
    for t in things
      values.push "(?)"
      bindings.push t

    things_rows = "(VALUES #{values.join(", ")} ) AS t (tthing)"

    filter_things_sql = @_knex("#{namespace}.events")
    .select("thing")
    .where(person: person)
    .whereIn('action', actions)
    .whereRaw("thing = t.tthing")
    .toSQL()

    bindings = bindings.concat(filter_things_sql.bindings)
   
    query = "select tthing from #{things_rows} where not exists (#{filter_things_sql.sql})"
    query = @questions_marks_to_dollar(query)
    @_knex.raw(query, bindings)
    .then( (rows) ->
      (r.tthing for r in rows.rows)
    )

  recently_actioned_things_by_people: (namespace, action, people, limit = 50) ->
    return bb.try(->[]) if people.length == 0

    bindings = [action]
    person_bindings = {}
    for p in people
      bindings.push(p)
      person_bindings[p] = "$#{bindings.length}"

    ql = []
    for p in people
      ql.push "(select person, thing, MAX(created_at) as max_ca from \"#{namespace}\".events
          where action = $1 and person = #{person_bindings[p]} group by person, thing order by max_ca DESC limit #{limit})"

    query = ql.join( " UNION ")

    @_knex.raw(query, bindings)
    .then( (ret) ->
      rows = ret.rows
      temp = {}
      for r in rows
        temp[r.person] = [] if temp[r.person] == undefined
        temp[r.person].push {thing: r.thing, last_actioned_at: r.max_ca.getTime()}

      temp
    )


  person_history: (namespace, person) ->
    @_knex("#{namespace}.events")
    .select('thing').max('created_at as created_at')
    .groupBy('thing')
    .orderByRaw("max(created_at) DESC")
    .whereRaw("action = t.caction")
    .whereRaw("person = #{person}")

  jaccard_query: (s1,s2) ->
    intersection = "(select count(*) from ((#{s1}) INTERSECT (#{s2})) as inter)::float"
    # case statement is needed for divide by zero problem
    union = "(select (case count(*) when 0 then 1 else count(*) end) from ((#{s1}) UNION (#{s2})) as uni)::float"
    
    # dont put the name of the action in the sql stopping sql injection
    "(#{intersection} / #{union})"

  jaccard_distance_for_limit: (namespace, person, limit) ->
    s1q = @person_history(namespace, person).toString()
    s2q = @person_history(namespace, 't.cperson').toString()
    s1 = "select x.thing from (#{s1q}) as x limit #{limit}"
    s2 = "select x.thing from (#{s2q}) as x limit #{limit}"
    
    "#{@jaccard_query(s1, s2)} as limit_distance"

  jaccard_distance_for_recent: (namespace, person, limit, days_ago) ->
    s1q = @person_history(namespace, person).toString()
    s2q = @person_history(namespace, 't.cperson').toString()

    s1 = "select x.thing from (#{s1q}) as x where 
          x.created_at > NOW() - '#{days_ago} day'::INTERVAL 
          order by x.created_at DESC limit #{limit}"
    s2 = "select x.thing from (#{s2q}) as x where 
          x.created_at > NOW() - '#{days_ago} day'::INTERVAL 
          order by x.created_at DESC limit #{limit}"

    "#{@jaccard_query(s1, s2)} as recent_distance"
  
  get_jaccard_distances_between_people: (namespace, person, people, actions, limit = 500, days_ago=14) ->
    return bb.try(->[]) if people.length == 0
    #TODO allow for arbitrary distance measurements here

    bindings = [person] 
    action_bindings = {}
    person_bindings = {}
    for action in actions
      bindings.push(action)
      action_bindings[action] = "$#{bindings.length}"

    for p in people
      bindings.push(p)
      person_bindings[p] = "$#{bindings.length}"

    limit_distance_query = @jaccard_distance_for_limit(namespace, '$1', limit)
    recent_distance_query = @jaccard_distance_for_recent(namespace, '$1', limit, days_ago)

    v_actions = ("(#{person_bindings[p]}, #{action_bindings[a]})" for a in actions for p in people).join(', ')

    query = "select cperson, caction, #{limit_distance_query}, #{recent_distance_query} from (VALUES #{v_actions} ) AS t (cperson, caction)"

    @_knex.raw(query, bindings)
    .then( (rows) ->
      limit_distance = {}
      recent_distance = {}
      for row in rows.rows
        recent_distance[row["cperson"]] ||= {}
        limit_distance[row["cperson"]] ||= {}

        limit_distance[row["cperson"]][row["caction"]] = row["limit_distance"]
        recent_distance[row["cperson"]][row["caction"]] = row["recent_distance"]

      [limit_distance, recent_distance]
    )


  calculate_similarities_from_person: (namespace, person, people, actions, person_history_limit, recent_event_days) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or people.length == 0

    #TODO fix this, it double counts newer listings [now-recentdate] then [now-limit] should be [now-recentdate] then [recentdate-limit]
    @get_jaccard_distances_between_people(namespace, person, people, actions, person_history_limit, recent_event_days)
    .spread( (event_weights, recent_event_weights) =>
      temp = {}
      #These weights start at a rate of 2:1 so to get to 80:20 we need 4:1*2:1 this could be wrong -- graham
      for p in people
        temp[p] = {}
        for ac in actions
          temp[p][ac] = ((recent_event_weights[p][ac] * 4) + (event_weights[p][ac] * 1))/5.0
      
      temp
    )

  count_events: (namespace) ->
    @_knex("#{namespace}.events").count()
    .then (count) -> parseInt(count[0].count)

  estimate_event_count: (namespace) ->
    @_knex.raw("SELECT reltuples::bigint 
      AS estimate 
      FROM pg_class 
      WHERE  oid = $1::regclass;"
      ,["#{namespace}.events"])
    .then( (rows) ->
      return 0 if rows.rows.length == 0
      return parseInt(rows.rows[0].estimate)
    )

  bootstrap: (namespace, stream) ->
    #stream of  person, action, thing, created_at, expires_at CSV
    #this will require manually adding the actions
    @_knex.client.acquireConnection()
    .then( (connection) =>
      deferred = bb.defer()
      pg_stream = connection.query(copyFrom("COPY \"#{namespace}\".events (person, action, thing, created_at, expires_at) FROM STDIN CSV"));
      counter = new CounterStream()
      stream.pipe(counter).pipe(pg_stream)
      .on('end', -> deferred.resolve(counter.count))
      .on('error', (error) -> deferred.reject(error))
      deferred.promise.finally( => @_knex.client.releaseConnection(connection))
    )
    
  # DATABASE CLEANING METHODS

  expire_events: (namespace) ->
    #removes the events passed their expiry date
    @_knex("#{namespace}.events").whereRaw('expires_at < NOW()').del()

  pre_compact: (namespace) ->
    @analyze(namespace)

  post_compact: (namespace) ->
    @analyze(namespace)


  remove_non_unique_events_for_people: (namespace, people) ->
    return bb.try( -> []) if people.length == 0
    promises = (@remove_non_unique_events_for_person(namespace, person) for person in people)
    bb.all(promises)

  remove_non_unique_events_for_person: (namespace, person) ->
    # TODO I would suggest doing it for active people. THIS IS WAY TOO SLOW!!!
    # http://stackoverflow.com/questions/1746213/how-to-delete-duplicate-entries
    bindings = [person]
    query = "DELETE FROM \"#{namespace}\".events e1 
    USING \"#{namespace}\".events e2 
    WHERE e1.person = $1 AND e1.expires_at is NULL AND e1.id <> e2.id AND e1.person = e2.person AND e1.action = e2.action AND e1.thing = e2.thing AND 
    (e1.created_at < e2.created_at OR (e1.created_at = e2.created_at AND e1.id < e2.id) )" #LEXICOGRAPHIC ORDERING for created at then id
    @_knex.raw(query, bindings)

  vacuum_analyze: (namespace) ->
    @_knex.raw("VACUUM ANALYZE \"#{namespace}\".events")

  analyze: (namespace) ->
    @_knex.raw("ANALYZE \"#{namespace}\".events")


  get_active_things: (namespace) ->
    #TODO WILL NOT WORK IF COMMA IN NAME
    #select most_common_vals from pg_stats where attname = 'thing';
    @_knex('pg_stats').select('most_common_vals').where(attname: 'thing', tablename: 'events', schemaname: namespace)
    .then((rows) ->
      return [] if not rows[0]
      common_str = rows[0].most_common_vals
      return [] if not common_str
      common_str = common_str[1..common_str.length-2]
      things = common_str.split(',')
      things
    )

  get_active_people: (namespace) ->
    #TODO WILL NOT WORK IF COMMA IN NAME
    #select most_common_vals from pg_stats where attname = 'person';
    @_knex('pg_stats').select('most_common_vals').where(attname: 'person', tablename: 'events', schemaname: namespace)
    .then((rows) ->
      return [] if not rows[0]
      common_str = rows[0].most_common_vals
      return [] if not common_str
      common_str = common_str[1..common_str.length-2]
      people = common_str.split(',')
      people
    )


  compact_people : (namespace, compact_database_person_action_limit, actions) ->
    @get_active_people(namespace)
    .then( (people) =>
      @remove_non_unique_events_for_people(namespace, people)
      .then( =>
        #remove events per (active) person action that exceed some number
        @truncate_people_per_action(namespace, people, compact_database_person_action_limit, actions)
      )
    )

  compact_things :  (namespace, compact_database_thing_action_limit, actions) ->
    @get_active_things(namespace)
    .then( (things) =>
      @truncate_things_per_action(namespace, things, compact_database_thing_action_limit, actions)
    )

  truncate_things_per_action: (namespace, things, trunc_size, actions) ->

    #TODO do the same thing for things
    return bb.try( -> []) if things.length == 0  

    #cut each action down to size
    promises = (@truncate_thing_actions(namespace, thing, trunc_size, action) for thing in things for action in actions)
    promises = _.flatten(promises)
    bb.all(promises)
    

  truncate_thing_actions: (namespace, thing, trunc_size, action) ->
    bindings = [thing, action]

    q = "delete from \"#{namespace}\".events as e 
         where e.id in 
         (select id from \"#{namespace}\".events where action = $2 and thing = $1
         order by created_at DESC offset #{trunc_size});"
    @_knex.raw(q ,bindings)


  truncate_people_per_action: (namespace, people, trunc_size, actions) ->
    #TODO do the same thing for things
    return bb.try( -> []) if people.length == 0  

    #cut each action down to size
    promises = (@truncate_person_actions(namespace, person, trunc_size, action) for person in people for action in actions)
    promises = _.flatten(promises)
    bb.all(promises)
    
    
  truncate_person_actions: (namespace, person, trunc_size, action) ->
    bindings = [person, action]
    q = "delete from \"#{namespace}\".events as e 
         where e.id in 
         (select id from \"#{namespace}\".events where action = $2 and person = $1
         order by created_at DESC offset #{trunc_size});"
    @_knex.raw(q ,bindings)
    
  remove_events_till_size: (namespace, number_of_events) ->
    #TODO move too offset method
    #removes old events till there is only number_of_events left
    query = "delete from #{namespace}.events where id not in (select id from #{namespace}.events order by created_at desc limit #{number_of_events})"
    @_knex.raw(query)

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return PSQLEventStoreManager)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = PSQLEventStoreManager;
