bb = require 'bluebird'
fs = require 'fs'
pg = require('pg');
copyFrom = require('pg-copy-streams').from;
_ = require 'underscore'

Errors = require './errors'

Transform = require('stream').Transform;
moment = require 'moment'


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
    now = new Date().toISOString()
    for e in events
      e.created_at = e.created_at || now
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

  find_events: (namespace, options = {}) ->

    options = _.defaults(options,
      size: 50
      page: 0
      current_datetime: new Date()
    )

    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format() if options.time_until_expiry

    q = @_knex("#{namespace}.events")
    .select("person", "action", "thing")
    .max('created_at as created_at')
    .max('expires_at as expires_at')
    .where('created_at', '<=', options.current_datetime)
    .orderBy('created_at', 'desc')
    .groupBy(['person', "action", "thing"])
    .limit(options.size)
    .offset(options.size*options.page)

    q.where('expires_at', '>', options.expires_after) if options.expires_after

    q = q.where(person: options.person) if options.person
    q = q.whereIn('person', options.people) if options.people

    q = q.where(action: options.action) if options.action
    q = q.whereIn('action', options.actions) if options.actions

    q = q.where(thing: options.thing) if options.thing
    q = q.whereIn('thing', options.things) if options.things

    q.then((rows)->
      rows
    )

  delete_events: (namespace, options = {}) ->
    q = @_knex("#{namespace}.events")

    q = q.where(person: options.person) if options.person
    q = q.whereIn('person', options.people) if options.people

    q = q.where(action: options.action) if options.action
    q = q.whereIn('action', options.actions) if options.actions

    q = q.where(thing: options.thing) if options.thing
    q = q.whereIn('thing', options.things) if options.things

    q.del()
    .then((delete_count)->
      {deleted: delete_count}
    )

  ###########################
  ####  NEIGHBOURHOOD  ######
  ###########################

  thing_neighbourhood: (namespace, thing, actions, options = {}) ->
    @_neighbourhood(namespace, "thing", "person", thing, actions, options)

  person_neighbourhood: (namespace, person, actions, options = {}) ->
    @_neighbourhood(namespace, "person", "thing", person, actions, options)

  _neighbourhood: (namespace, column1, column2, value, actions, options) ->
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      neighbourhood_size: 100
      history_search_size: 500
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    one_degree_away = @_one_degree_away(namespace, column1, column2, value, actions, options)
    unexpired_events = @_unexpired_events(namespace, column1, column2, value, actions, options)

    @_knex(one_degree_away.as('x'))
    .select("x.#{column1}", 'x.created_at_day', 'x.count')
    .whereExists(unexpired_events)
    .orderByRaw("x.created_at_day DESC, x.count DESC")
    .limit(options.neighbourhood_size)
    .then( (rows) ->
      (r[column1] for r in rows)
    )

  _unexpired_events: (namespace, column1, column2, value, actions, options) ->
    @_knex("#{namespace}.events")
    .select(column1)
    .whereRaw('expires_at IS NOT NULL')
    .where('expires_at', '>', options.expires_after)
    .where('created_at', '<=', options.current_datetime)
    .whereIn('action', actions)
    .whereRaw("#{column1} = x.#{column1}")


  _one_degree_away: (namespace, column1, column2, value, actions, options) ->
    query_hash = {}
    query_hash[column1] = value #e.g. {person: person}

    recent_events = @_knex("#{namespace}.events")
    .select("person", "action", "thing", "created_at")
    .where(query_hash)
    .whereIn('action', actions)
    .orderByRaw('created_at DESC')
    .limit(options.history_search_size)

    @_knex(recent_events.as('e'))
    .innerJoin("#{namespace}.events as f", -> @on("e.#{column2}", "f.#{column2}").on('e.action','f.action').on("f.#{column1}",'!=', "e.#{column1}"))
    .where("e.#{column1}", value)
    .whereIn('f.action', actions)
    .where('f.created_at', '<=', options.current_datetime)
    .where('e.created_at', '<=', options.current_datetime)
    .select(@_knex.raw("f.#{column1}, date_trunc('day', max(e.created_at)) as created_at_day, count(f.#{column1}) as count"))
    .groupBy("f.#{column1}")
    .orderByRaw("created_at_day DESC, count(f.#{column1}) DESC")

  ##################################
  ####  END OF NEIGHBOURHOOD  ######
  ##################################


  filter_things_by_previous_actions: (namespace, person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0

    bindings = {person: person}
    action_values = []
    for a, ai in actions
      akey = "action_#{ai}"
      bindings[akey] = a
      action_values.push(" :#{akey} ")

    action_values = action_values.join(',')

    thing_values = []
    for t, ti in things
      tkey = "thing_#{ti}"
      bindings[tkey] = t
      thing_values.push "( :#{tkey} )"

    thing_values = thing_values.join(", ")

    things_rows = "(VALUES #{thing_values} ) AS t (tthing)"

    filter_things_sql = @_knex("#{namespace}.events")
    .select("thing")
    .whereRaw("person = :person")
    .whereRaw("action in (#{action_values})")
    .whereRaw("thing = t.tthing")
    .toSQL()

    query = "select tthing from #{things_rows} where not exists (#{filter_things_sql.sql})"

    @_knex.raw(query, bindings)
    .then( (rows) ->
      (r.tthing for r in rows.rows)
    )

  ##############################
  ##### RECENT EVENTS  #########
  ##############################

  _recent_events: (namespace, column1, actions, values, options = {}) ->
    return bb.try(->[]) if values.length == 0 || actions.length == 0

    options = _.defaults(options,
      related_things_limit: 10
      time_until_expiry: 0
      current_datetime: new Date()
    )

    expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    bindings = {expires_after: expires_after, now: options.current_datetime}

    action_values = []
    for a, ai in actions
      akey = "action_#{ai}"
      bindings[akey] = a
      action_values.push(" :#{akey} ")

    action_values = action_values.join(',')
    ql = []
    for v,i in values
      key = "value_#{i}"
      bindings[key] = v
      ql.push "(select person, thing, MAX(created_at) as max_ca, MAX(expires_at) as max_ea from \"#{namespace}\".events
          where created_at <= :now and action in (#{action_values}) and #{column1} = :#{key} and (expires_at > :expires_after ) group by person, thing order by max_ca DESC limit #{options.related_things_limit})"

    query = ql.join( " UNION ")
    query += " order by max_ca DESC" if ql.length > 1

    @_knex.raw(query, bindings)
    .then( (ret) ->
      rows = ret.rows
      recommendations = []
      for r in rows
        recommendations.push {
          person: r.person
          thing: r.thing
          last_actioned_at: r.max_ca
          last_expires_at: r.max_ea
        }

      recommendations
    )

  recent_recommendations_by_people: (namespace, actions, people, options) ->
    @_recent_events(namespace, 'person', actions, people, options)

  recent_recommendations_for_things: (namespace, actions, things, options) ->
    @_recent_events(namespace, 'thing', actions, things, options)


  _history: (namespace, column1, column2, value) ->
    @_knex("#{namespace}.events")
    .select(column2).max('created_at as created_at')
    .groupBy(column2)
    .orderByRaw("max(created_at) DESC")
    .whereRaw('created_at <= :now')
    .whereRaw("action = t.caction")
    .whereRaw("#{column1} = #{value}")

  jaccard_query: (s1,s2) ->
    intersection = "(select count(*) from ((#{s1}) INTERSECT (#{s2})) as inter)::float"
    # case statement is needed for divide by zero problem
    union = "(select (case count(*) when 0 then 1 else count(*) end) from ((#{s1}) UNION (#{s2})) as uni)::float"
    
    # dont put the name of the action in the sql stopping sql injection
    "(#{intersection} / #{union})"

  jaccard_distance_for_limit: (namespace, column1, column2, limit) ->
    s1q = @_history(namespace, column1, column2, ':value').toString()
    s2q = @_history(namespace, column1, column2, 't.cvalue').toString()

    s1 = "select x.#{column2} from (#{s1q}) as x limit #{limit}"
    s2 = "select x.#{column2} from (#{s2q}) as x limit #{limit}"
    
    "#{@jaccard_query(s1, s2)} as limit_distance"

  jaccard_distance_for_recent: (namespace, column1, column2, limit, days_ago) ->
    #TODO remove now
    s1q = @_history(namespace, column1, column2, ':value').toString()
    s2q = @_history(namespace, column1, column2, 't.cvalue').toString()

    s1 = "select x.#{column2} from (#{s1q}) as x where 
          x.created_at >= Date( :now ) - '#{days_ago} day'::INTERVAL 
          order by x.created_at DESC limit #{limit}"
    s2 = "select x.#{column2} from (#{s2q}) as x where 
          x.created_at >= Date( :now ) - '#{days_ago} day'::INTERVAL 
          order by x.created_at DESC limit #{limit}"

    "#{@jaccard_query(s1, s2)} as recent_distance"
  
  get_jaccard_distances: (namespace, column1, column2, value, values, actions, limit = 500, days_ago=14, now = new Date())->
    return bb.try(->[]) if values.length == 0

    bindings = {value: value, now: now} 

    limit_distance_query = @jaccard_distance_for_limit(namespace,column1, column2, limit)
    recent_distance_query = @jaccard_distance_for_recent(namespace, column1, column2, limit, days_ago)

    v_actions = []
    for a, ai in actions
      akey = "action_#{ai}"
      bindings[akey] =  a
      for v, vi in values
        vkey = "value_#{vi}"
        bindings[vkey] =  v
        v_actions.push("( :#{vkey}, :#{akey} )")

    v_actions = v_actions.join(', ')

    query = "select cvalue, caction, #{limit_distance_query}, #{recent_distance_query} from (VALUES #{v_actions} ) AS t (cvalue, caction)"

    @_knex.raw(query, bindings)
    .then( (rows) ->
      limit_distance = {}
      recent_distance = {}
      for row in rows.rows
        recent_distance[row["cvalue"]] ||= {}
        limit_distance[row["cvalue"]] ||= {}

        limit_distance[row["cvalue"]][row["caction"]] = row["limit_distance"]
        recent_distance[row["cvalue"]][row["caction"]] = row["recent_distance"]

      [limit_distance, recent_distance]
    )

  _similarities: (namespace, column1, column2, value, values, actions, options={}) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or values.length == 0
    options = _.defaults(options,
      history_search_size: 500
      recent_event_days: 14
      current_datetime: new Date()
    )

    #TODO fix this, it double counts newer things [now-recentdate] then [now-limit] should be [now-recentdate] then [recentdate-limit]
    @get_jaccard_distances(namespace, column1, column2, value, values, actions, options.history_search_size, options.recent_event_days, options.current_datetime)
    .spread( (event_weights, recent_event_weights) =>
      temp = {}
      #These weights start at a rate of 2:1 so to get to 80:20 we need 4:1*2:1 this could be wrong -- graham
      for v in values
        temp[v] = {}
        for ac in actions
          temp[v][ac] = ((recent_event_weights[v][ac] * 4) + (event_weights[v][ac] * 1))/5.0
      
      temp
    )

  calculate_similarities_from_thing: (namespace, thing, things, actions, options={}) ->
    @_similarities(namespace, 'thing', 'person', thing, things, actions, options)

  calculate_similarities_from_person: (namespace, person, people, actions, options={}) ->
    @_similarities(namespace, 'person', 'thing', person, people, actions, options)




  count_events: (namespace) ->
    @_knex("#{namespace}.events").count()
    .then (count) -> parseInt(count[0].count)

  estimate_event_count: (namespace) ->
    @_knex.raw("SELECT reltuples::bigint 
      AS estimate 
      FROM pg_class 
      WHERE  oid = :ns ::regclass;"
      ,{ns: "#{namespace}.events"})
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

  pre_compact: (namespace) ->
    @analyze(namespace)

  post_compact: (namespace) ->
    @analyze(namespace)


  remove_non_unique_events_for_people: (namespace, people) ->
    return bb.try( -> []) if people.length == 0
    promises = (@remove_non_unique_events_for_person(namespace, person) for person in people)
    bb.all(promises)

  remove_non_unique_events_for_person: (namespace, person, limit=100) ->
    bb.all([
      @remove_non_unique_events_for_person_without_expiry(namespace, person, limit),
      @remove_non_unique_events_for_person_with_expiry(namespace, person, limit),
    ])

  remove_non_unique_events_for_person_with_expiry: (namespace, person, limit) ->
    bindings = {person: person}
    query = "DELETE FROM \"#{namespace}\".events as e where e.id IN 
    (SELECT e2.id FROM \"#{namespace}\".events e1, \"#{namespace}\".events e2 
    WHERE e1.person = :person 
    AND e1.expires_at is NOT NULL AND e2.expires_at is NOT NULL
    AND e1.id <> e2.id 
    AND e1.person = e2.person 
    AND e1.action = e2.action 
    AND e1.thing = e2.thing 
    AND (e1.expires_at > e2.expires_at OR (e1.expires_at = e2.expires_at AND e1.id < e2.id))
    order by e1.id 
    LIMIT #{limit})"
    #LEXICOGRAPHIC ORDERING for expires at then id
    @_knex.raw(query, bindings)

  remove_non_unique_events_for_person_without_expiry: (namespace, person, limit) ->
    # http://stackoverflow.com/questions/1746213/how-to-delete-duplicate-entries
    bindings = {person: person}
    query = "DELETE FROM \"#{namespace}\".events as e where e.id IN 
    (SELECT e2.id FROM \"#{namespace}\".events e1, \"#{namespace}\".events e2 
    WHERE e1.person = :person
    AND e1.expires_at is NULL AND e2.expires_at is NULL
    AND e1.id <> e2.id 
    AND e1.person = e2.person 
    AND e1.action = e2.action 
    AND e1.thing = e2.thing 
    AND (e1.created_at > e2.created_at OR (e1.created_at = e2.created_at AND e1.id < e2.id))
    order by e1.id 
    LIMIT #{limit})"
    #LEXICOGRAPHIC ORDERING for created at then id
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
    bindings = {thing: thing, action: action}

    q = "delete from \"#{namespace}\".events as e 
         where e.id in 
         (select id from \"#{namespace}\".events where action = :action and thing = :thing
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
    bindings = {person: person, action: action}
    q = "delete from \"#{namespace}\".events as e 
         where e.id in 
         (select id from \"#{namespace}\".events where action = :action and person = :person
         order by created_at DESC offset #{trunc_size});"
    @_knex.raw(q ,bindings)
    
  remove_events_till_size: (namespace, number_of_events) ->
    #TODO move too offset method
    #removes old events till there is only number_of_events left
    query = "delete from #{namespace}.events where id not in (select id from #{namespace}.events order by created_at desc limit #{number_of_events})"
    @_knex.raw(query)


module.exports = PSQLEventStoreManager;
