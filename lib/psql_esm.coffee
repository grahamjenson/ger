bb = require 'bluebird'
fs = require 'fs'
_ = require 'lodash'

Errors = require './errors'

moment = require 'moment'

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
    @list_namespaces()
    .then((namespaces) =>
      _.contains(namespaces, namespace)
    )

  list_namespaces: () ->
    @_knex.raw("SELECT table_schema FROM information_schema.tables WHERE table_name = 'events'")
    .then( (res) ->
      ret = _.uniq(res.rows.map( (row) -> row.table_schema))
      ret = ret.filter((x) -> x != 'default')
      ret
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
      # console.log error.message
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
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      neighbourhood_size: 100
      neighbourhood_search_size: 500
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    one_degree_away = @_one_degree_away(namespace, 'thing', 'person', thing, actions, options)
    .orderByRaw("action_count DESC")

    @_knex(one_degree_away.as('x'))
    .where('x.last_expires_at', '>', options.expires_after)
    .where('x.last_actioned_at', '<=', options.current_datetime)
    .orderByRaw("x.action_count DESC")
    .limit(options.neighbourhood_size)
    .then( (rows) ->
      for row in rows
        row.people = _.uniq(row.person) # difficult in postgres
      rows
    )

  person_neighbourhood: (namespace, person, actions, options = {}) ->
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      neighbourhood_size: 100
      neighbourhood_search_size: 500
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    one_degree_away = @_one_degree_away(namespace, 'person', 'thing', person, actions, options)
    .orderByRaw("created_at_day DESC, action_count DESC")

    unexpired_events = @_unexpired_events(namespace, actions, options)

    @_knex(one_degree_away.as('x'))
    .whereExists(unexpired_events)
    .orderByRaw("x.created_at_day DESC, x.action_count DESC")
    .limit(options.neighbourhood_size)
    .then( (rows) ->
      (row.person for row in rows)
    )


  _unexpired_events: (namespace, actions, options) ->
    @_knex("#{namespace}.events")
    .select('person')
    .whereRaw('expires_at IS NOT NULL')
    .where('expires_at', '>', options.expires_after)
    .where('created_at', '<=', options.current_datetime)
    .whereIn('action', actions)
    .whereRaw("person = x.person")

  _one_degree_away: (namespace, column1, column2, value, actions, options) ->
    query_hash = {}
    query_hash[column1] = value #e.g. {person: person} or {thing: thing}

    recent_events = @_knex("#{namespace}.events")
    .where(query_hash)
    .whereIn('action', actions)
    .orderByRaw('created_at DESC')
    .limit(options.neighbourhood_search_size)

    @_knex(recent_events.as('e'))
    .innerJoin("#{namespace}.events as f", -> @on("e.#{column2}", "f.#{column2}").on("f.#{column1}",'!=', "e.#{column1}"))
    .where("e.#{column1}", value)
    .whereIn('f.action', actions)
    .where('f.created_at', '<=', options.current_datetime)
    .where('e.created_at', '<=', options.current_datetime)
    .select(@_knex.raw("f.#{column1}, MAX(f.created_at) as last_actioned_at, MAX(f.expires_at) as last_expires_at, array_agg(f.#{column2}) as #{column2}, date_trunc('day', max(e.created_at)) as created_at_day, count(f.#{column1}) as action_count"))
    .groupBy("f.#{column1}")

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
      recommendations_per_neighbour: 10
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
      ql.push "(select person, thing, MAX(created_at) as last_actioned_at, MAX(expires_at) as last_expires_at from \"#{namespace}\".events
          where created_at <= :now and action in (#{action_values}) and #{column1} = :#{key} and (expires_at > :expires_after ) group by person, thing order by last_actioned_at DESC limit #{options.recommendations_per_neighbour})"

    query = ql.join( " UNION ")
    query += " order by last_actioned_at DESC" if ql.length > 1

    @_knex.raw(query, bindings)
    .then( (ret) ->
      ret.rows
    )

  recent_recommendations_by_people: (namespace, actions, people, options) ->
    @_recent_events(namespace, 'person', actions, people, options)


  _history: (namespace, column1, column2, value, al_values, limit) ->
    @_knex("#{namespace}.events")
    .select(column2, "action").max('created_at as created_at')
    .groupBy(column2, "action")
    .whereRaw("action in ( #{al_values} )")
    .orderByRaw("max(created_at) DESC")
    .whereRaw('created_at <= :now')
    .whereRaw("#{column1} = #{value}")
    .limit(limit)

  cosine_query: (namespace, s1, s2) ->
    numerator_1 = "(select (tbl1.weight * tbl2.weight) as weight from (#{s1}) tbl1 join (#{s2}) tbl2 on tbl1.value = tbl2.value)"
    numerator_2 = "(select SUM(n1.weight) from (#{numerator_1}) as n1)"

    denominator_1 = "(select SUM(power(s1.weight, 2.0)) from (#{s1}) as s1)"
    denominator_2 = "(select SUM(power(s2.weight, 2.0)) from (#{s2}) as s2)"
    # numerator_2
    # numberator = "(#{numerator_1} * #{numerator_2})"
    # # case statement is needed for divide by zero problem

    # denominator = "( (|/ #{denominator_1}) *  )"
    # if null return 0
    "COALESCE( (#{numerator_2} / ((|/ #{denominator_1}) * (|/ #{denominator_2})) ), 0)"

  cosine_distance: (namespace, column1, column2, limit, a_values, al_values) ->
    s1q = @_history(namespace, column1, column2, ':value', al_values, limit).toString()
    s2q = @_history(namespace, column1, column2, 't.cvalue', al_values, limit).toString()

    #decay is weight * days
    weighted_actions = "select cast(a.weight as float) * power( :event_decay_rate, - date_part('day', age( :now , x.created_at ))) from (VALUES #{a_values}) AS a (action,weight) where x.action = a.action"

    s1_weighted = "select x.#{column2}, (#{weighted_actions}) as weight from (#{s1q}) as x"
    s2_weighted = "select x.#{column2}, (#{weighted_actions}) as weight from (#{s2q}) as x"

    # There are two options here, either select max value, or select most recent.
    # This might be a configuration in the future
    # e.g. if a person purchases a thing, then views it the most recent action is wrong
    # e.g. if a person gives something a 5 star rating then changes it to 1 star, the max value is wrong

    s1 = "select ws.#{column2} as value, max(ws.weight) as weight from (#{s1_weighted}) as ws where ws.weight != 0 group by ws.#{column2}"
    s2 = "select ws.#{column2} as value, max(ws.weight) as weight from (#{s2_weighted}) as ws where ws.weight != 0 group by ws.#{column2}"

    "#{@cosine_query(namespace, s1, s2)} as cosine_distance"

  get_cosine_distances: (namespace, column1, column2, value, values, actions, limit, event_decay_rate, now) ->
    return bb.try(->[]) if values.length == 0
    bindings = {value: value, now: now, event_decay_rate: event_decay_rate}

    action_list = []
    for action, weight of actions
      #making it easier to work with actions
      action_list.push {action: action, weight, weight}

    a_values = []
    al_values = []
    for a, ai in action_list
      akey = "action_#{ai}"
      wkey = "weight_#{ai}"
      bindings[akey] = a.action
      bindings[wkey] = a.weight
      a_values.push("( :#{akey}, :#{wkey} )")
      al_values.push(":#{akey}")

    a_values = a_values.join(', ')
    al_values = al_values.join(' , ')

    v_values = []

    for v, vi in values
      vkey = "value_#{vi}"
      bindings[vkey] =  v
      v_values.push("( :#{vkey} )")

    v_values = v_values.join(', ')


    cosine_distance = @cosine_distance(namespace, column1, column2, limit, a_values, al_values, event_decay_rate)

    query = "select cvalue, #{cosine_distance} from (VALUES #{v_values} ) AS t (cvalue)"

    @_knex.raw(query, bindings)
    .then( (rows) ->
      similarities = {}
      for row in rows.rows
        similarities[row.cvalue] = row.cosine_distance

      similarities
    )

  _similarities: (namespace, column1, column2, value, values, actions, options={}) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or values.length == 0
    options = _.defaults(options,
      similarity_search_size: 500
      event_decay_rate: 1
      current_datetime: new Date()
    )
    #TODO history search size should be more [similarity history search size]
    @get_cosine_distances(namespace, column1, column2, value, values, actions, options.similarity_search_size, options.event_decay_rate, options.current_datetime)

  calculate_similarities_from_thing: (namespace, thing, things, actions, options={}) ->
    @_similarities(namespace, 'thing', 'person', thing, things, actions, options)

  calculate_similarities_from_person: (namespace, person, people, actions, options={}) ->
    @_similarities(namespace, 'person', 'thing', person, people, actions, options)




  count_events: (namespace) ->
    @_knex("#{namespace}.events").count()
    .then (count) -> parseInt(count[0].count)

  estimate_event_count: (namespace) ->
    @_knex.raw("SELECT cast(reltuples as bigint)
      AS estimate
      FROM pg_class
      WHERE  oid = cast(:ns as regclass);"
      ,{ns: "#{namespace}.events"})
    .then( (rows) ->
      return 0 if rows.rows.length == 0
      return parseInt(rows.rows[0].estimate)
    )

  # DATABASE CLEANING METHODS

  pre_compact: (namespace) ->
    @analyze(namespace)

  post_compact: (namespace) ->
    @analyze(namespace)

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
      @truncate_people_per_action(namespace, people, compact_database_person_action_limit, actions)
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
    promise = bb.try( ->)
    for thing in things
      for action in actions
        do (thing, action) =>
          promise = promise.then(=> @truncate_thing_actions(namespace, thing, trunc_size, action) )

    promise


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
    promise = bb.try( ->)
    for person in people
      for action in actions
        do (person, action) =>
          promise = promise.then(=> @truncate_person_actions(namespace, person, trunc_size, action) )

    promise


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
