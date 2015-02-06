bb = require 'bluebird'
fs = require 'fs'
crypto = require 'crypto'
moment = require 'moment'
shasum = null
split = require 'split'
_ = require 'underscore'
#The only stateful thing in this ESM is the UUID (schema), it should not be changed

class EventStoreMapper


  #INSTANCE ACTIONS
  constructor: (@namespace, orms) ->
    @_r = orms.r

  try_create_table: (table, table_list) ->
    if table in table_list
      return bb.try(-> false)
    else
      return @_r.tableCreate(table).run().then(-> true)

  try_delete_table: (table, table_list) ->
    if table in table_list
      #DELETES all the events because drop and create are VERY slow
      return @_r.table(table).delete().run().then(( ret ) -> true)
    else
      return bb.try(-> false)

  try_drop_table: (table, table_list) ->
    if table in table_list
      #DELETES all the events because drop and create are VERY slow
      return @_r.tableDrop(table).run().then(( ret ) -> true)
    else
      return bb.try(-> false)

  destroy: ->
    @_r.tableList().run().then( (list) =>
      bb.all([
        @try_delete_table("#{@namespace}_events", list),
        @try_drop_table("#{@namespace}_actions", list) #only drop actions because it costs so much to recreate events indexes
      ])
    )

  exists: ->
    @_r.tableList().run().then( (list) =>
      "#{@namespace}_events" in list and "#{@namespace}_actions" in list
    )

  set_namespace: (namespace)->
    @namespace = namespace
    
  initialize: ->
    @_r.tableList().run().then( (list) =>
      bb.all([
        @try_create_table("#{@namespace}_events", list)
        @try_create_table("#{@namespace}_actions", list)
      ])
    )
    .spread( (events_created, actions_created) =>
      promises = []
      if events_created
        promises = promises.concat([@_r.table("#{@namespace}_events").indexCreate("created_at").run(),
          @_r.table("#{@namespace}_events").indexCreate("expires_at").run(),
          @_r.table("#{@namespace}_events").indexCreate("person").run(),
          @_r.table("#{@namespace}_events").indexCreate("person_thing",[@_r.row("person"),@_r.row("thing")]).run(),
          @_r.table("#{@namespace}_events").indexCreate("action_thing",[@_r.row("action"),@_r.row("thing")]).run(),
          @_r.table("#{@namespace}_events").indexCreate("person_action",[@_r.row("person"),@_r.row("action")]).run(),
          @_r.table("#{@namespace}_events").indexCreate("person_action_created_at",[@_r.row("person"),@_r.row("action"),@_r.row("created_at")]).run(),
          @_r.table("#{@namespace}_events").indexCreate("thing").run(),
          @_r.table("#{@namespace}_events").indexCreate("action").run(),
          @_r.table("#{@namespace}_events").indexWait().run()
        ])
      bb.all(promises)
    )

  clear_tables: ->
    clear_tables(@_r)

  analyze: ->
    bb.try(-> true)

  vacuum_analyze: ->
    bb.try(-> true)

  convert_date: (date) ->
    if date
      date = new Date(date)
      if date._isAMomentObject
        date = date.format()
      valid_date = moment(date, moment.ISO_8601);
      if(valid_date.isValid())
        ret = @_r.ISO8601(date)
      else
        ret = @_r.ISO8601(date.toISOString())
      return ret
    else
      return null

  add_event: (person, action, thing, dates = {}) ->
    created_at = @convert_date(dates.created_at) || @_r.ISO8601(new Date().toISOString())
    expires_at =  @convert_date(dates.expires_at)

    @add_event_to_db(person, action, thing, created_at, expires_at)

  upsert: (table, insert_attr, identity_attr,overwrite = true) ->
    if overwrite
      conflict_method = "update"
    else
      conflict_method = "error"
    shasum = crypto.createHash("sha256")
    shasum.update(identity_attr.toString())
    insert_attr.id = shasum.digest("hex")
    @_r.table(table).insert(insert_attr, {conflict: conflict_method, durability: "soft"}).run()

  _event_selection: (person, action, thing) ->
    single_selection = false
    index = null
    index_fields = null
    if person and action and thing
      single_selection = true
    else if person and action
      index = "person_action"
      index_fields = [person,action]
    else if person and thing
      index = "person_thing"
      index_fields = [person,thing]
    else if action and thing
      index = "action_thing"
      index_fields = [action, thing]
    else if person and !action and !thing
      index = "person"
      index_fields = person
    else if action and !person and !thing
      index = "action"
      index_fields = action
    else if thing and !action and !person
      index = "thing"
      index_fields = thing
    q = @_r.table("#{@namespace}_events")
    if single_selection
      shasum = crypto.createHash("sha256")
      shasum.update(person.toString() + action + thing)
      id = shasum.digest("hex")
      q = q.get(id)
    else if index
      q = q.getAll(index_fields,{index: index})
      q = q.orderBy(@_r.desc('created_at'))
    return q

  find_events: (person, action, thing, options = {}) ->
    options = _.defaults(options, {size: 50, page: 0})
    size = options.size
    page = options.page

    if person and action and thing
      #Fast single look up
      @_event_selection(person, action, thing)
      .run({useOutdated: true})
      .then( (e) -> 
        return [] if !e
        [e] # have to put it into a list
      ) 
    else
      #slower multi-event lookup
      @_event_selection(person, action, thing)
      .slice(page*size, size*(page + 1))
      .run({useOutdated: true})
  
  delete_events: (person, action, thing) ->
    @_event_selection(person, action, thing)
    .delete()
    .run({useOutdated: true,durability: "soft"})

  add_event_to_db: (person, action, thing, created_at, expires_at = null) ->
    insert_attr = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
    identity_attr = person.toString() + action + thing
    @upsert("#{@namespace}_events", insert_attr, identity_attr)

  set_action_weight: (action, weight, overwrite = true) ->
    now = new Date()
    insert_attr =  {action: action, weight: +weight, created_at: now, updated_at: now}
    identity_attr = action
    @upsert("#{@namespace}_actions", insert_attr, identity_attr,overwrite)

  person_history_count: (person) ->
    @_r.table("#{@namespace}_events").getAll(person,{index: "person"})("thing")
    .default([]).distinct().count().run({useOutdated: true})

  get_actions: ->
    @_r.table("#{@namespace}_actions")
    .map((row) ->
      return {
        key: row("action"),
        weight: row("weight")
      }
    )
    .run({useOutdated: true})
    .then( (rows) =>
      rows = _.sortBy(rows, (a) -> - a.weight)
      rows
    )

  get_action_weight: (action) ->
    shasum = crypto.createHash("sha256")
    shasum.update(action.toString())
    id = shasum.digest("hex")
    @_r.table("#{@namespace}_actions").get(id)('weight').default(null).run({useOutdated: true})

  find_similar_people: (person, actions, action, limit = 100, search_limit = 500) ->
    return bb.try(-> []) if !actions or actions.length == 0
    r = @_r
    person_actions = ([person, a] for a in actions)
    r.table("#{@namespace}_events").getAll(person_actions..., {index: "person_action"} )
    .orderBy(r.desc('created_at'))
    .limit(search_limit)
    .concatMap((row) =>
      r.table("#{@namespace}_events").getAll([row("action"),row("thing")],{index: "action_thing"})
      .filter((row) ->
        row("person").ne(person)
      )
      .map((row) ->
        {person: row("person"),action: row("action")}
      )
    )
    .group("person")
    .ungroup()
    .filter((row) =>
      row("reduction")("action").contains(action)
    )
    .map((row) =>
      {
        person: row("group"),
        count: row("reduction").count()
      }
    )
    .orderBy(r.desc('count'))
    .limit(limit)("person")
    .run({useOutdated: true})


  filter_things_by_previous_actions: (person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0
    indexes = []
    indexes.push([person, action]) for action in actions
    @_r.expr(things).setDifference(@_r.table("#{@namespace}_events").getAll(@_r.args(indexes),{index: "person_action"})
    .coerceTo("ARRAY")("thing")).run({useOutdated: true})

  recently_actioned_things_by_people: (action, people, limit = 50) ->
    return bb.try(->[]) if people.length == 0
    r = @_r
    people_actions = []
    for p in people
      people_actions.push [p,action]

    r.table("#{@namespace}_events")
    .getAll(r.args(people_actions), {index: 'person_action'})
    .group("person","action")
    .orderBy(r.desc("created_at"))
    .limit(limit)
    .map((row) ->
      {
        thing: row("thing"),
        last_actioned_at: row("created_at").toEpochTime()
      }
    )
    .ungroup()
    .map((row) =>
      r.object(row("group").nth(0).coerceTo("string"),row("reduction"))
    )
    .reduce((a,b) ->
      a.merge(b)
    )
    .default({})
    .run({useOutdated: true})

  get_jaccard_distances_between_people: (person, people, actions, limit = 500, days_ago=14) ->
    return bb.try(->[]) if people.length == 0
    r = @_r

    people_actions = []

    for a in actions
      people_actions.push [person, a]
      for p in people
        people_actions.push [p,a]

    r.table("#{@namespace}_events")
    .getAll(r.args(people_actions), {index: 'person_action'})
    .group("person","action")
    .orderBy(r.desc("created_at"))
    .limit(limit).ungroup()
    .map((row) ->
      r.object(
        row("group").nth(0).coerceTo("string"),
        r.object(
          row("group").nth(1).coerceTo("string"),
          {
            history: row("reduction")("thing"),
            recent_history: row("reduction").filter((row) =>
              row("created_at").during(r.now().sub(days_ago * 24 * 60 * 60),r.now())
            )("thing")
          }
        )
      )
    ).reduce((a,b) ->
        a.merge(b)
    ).do((rows) ->
      r.expr(actions).concatMap((a) ->
        _a = r.expr(a).coerceTo("string")
        person_histories = rows(r.expr(person).coerceTo("string"))(_a).default(null)
        person_history = r.branch(person_histories.ne(null), person_histories("history"),[])
        person_recent_history = r.branch(person_histories.ne(null), person_histories("recent_history"),[])
        r.expr(people).map((p) ->
          _p = r.expr(p).coerceTo("string")
          p_histories = rows(_p)(_a).default(null)
          p_history = r.branch(p_histories.ne(null),p_histories("history"),[])
          p_recent_history = r.branch(p_histories.ne(null),p_histories("recent_history"),[])
          limit_distance = r.object(_p,r.object(_a,r.expr(p_history).setIntersection(person_history).count().div(r.expr([r.expr(p_history).setUnion(person_history).count(),1]).max())))
          recent_distance = r.object(_p,r.object(_a,r.expr(p_recent_history).setIntersection(person_recent_history).count().div(r.expr([r.expr(p_recent_history).setUnion(person_recent_history).count(),1]).max())))
          {
              limit_distance: limit_distance,
              recent_distance: recent_distance
          }
        )
      )
      .reduce((a,b) ->
        {
          limit_distance: a("limit_distance").merge(b("limit_distance")),
          recent_distance: a("recent_distance").merge(b("recent_distance"))
        }
      )
    )
    .do((data) ->
      r.expr(people).concatMap((p) ->
        _p = r.expr(p).coerceTo("string")
        r.expr(actions).map((a) ->
          _a = r.expr(a).coerceTo("string")
          recent_weight = r.branch(data("recent_distance")(_p).ne(null).and(data("recent_distance")(_p)(_a).ne(null)),data("recent_distance")(_p)(_a), 0)
          event_weight = r.branch(data("limit_distance")(_p).ne(null).and(data("limit_distance")(_p)(_a).ne(null)),data("limit_distance")(_p)(_a), 0)
          r.object(_p,r.object(_a, recent_weight.mul(4).add(event_weight.mul(1)).div(5)))
        )
      ).reduce((a,b) ->
          a.merge(b)
      )
    )
    .run({useOutdated: true})

  calculate_similarities_from_person: (person, people, actions, person_history_limit, recent_event_days) ->
    @get_jaccard_distances_between_people(person, people, actions, person_history_limit, recent_event_days)

  has_event: (person, action, thing) ->
    shasum = crypto.createHash("sha256")
    shasum.update(person.toString() + action + thing)
    id = shasum.digest("hex")
    @_r.table("#{@namespace}_events").get(id).ne(null).run({useOutdated: true})

  has_action: (action) ->
    shasum = crypto.createHash("sha256")
    shasum.update(action.toString())
    id = shasum.digest("hex")
    @_r.table("#{@namespace}_actions").get(id).ne(null).run({useOutdated: true})

  count_events: ->
    @_r.table("#{@namespace}_events").count().run({useOutdated: true})

  estimate_event_count: ->
    @_r.table("#{@namespace}_events").count().run({useOutdated: true})

  count_actions: ->
    @_r.table("#{@namespace}_actions").count().run({useOutdated: true})

  bootstrap: (stream) ->
    #stream of  person, action, thing, created_at, expires_at CSV
    #this will require manually adding the actions
    r_bulk = []
    chain_promise = bb.try(-> true)
    deferred = bb.defer()
    counter = 0
    stream.pipe(split(/^/gm)).on("data", (row) =>
      row = row.toString().trim()
      data = row.split(",")
      if data.length > 1
        shasum = crypto.createHash("sha256")
        shasum.update(data[0] + data[1] + data[2])
        id = shasum.digest("hex")
        r_bulk.push({
            id: id,
            person: data[0],
            action: data[1],
            thing: data[2],
            created_at: @convert_date(data[3]),
            expires_at: @convert_date(data[4])
        })

        if r_bulk.length > 200
          counter += r_bulk.length
          chain_promise = bb.all([chain_promise, @_r.table("#{@namespace}_events").insert(r_bulk,{conflict: "replace", durability: "soft"}).run()])
          r_bulk = []

    ).on("end", =>
      return if r_bulk.length == 0
      counter += r_bulk.length
      bb.all([chain_promise, @_r.table("#{@namespace}_events").insert(r_bulk,{conflict: "replace", durability: "soft"}).run()])
      .then(-> deferred.resolve(counter))
    )

    deferred.promise

  # DATABASE CLEANING METHODS

  expire_events: ->
    #removes the events passed their expiry date
    @_r.table("#{@namespace}_events").between(null,@_r.now(),{index: "expires_at",rightBound: "closed"}).delete().run({useOutdated: true,durability: "soft"})

  pre_compact: ->
    bb.try -> true

  post_compact: ->
    bb.try -> true

  remove_non_unique_events_for_people: (people) ->
    bb.try( -> [])

  remove_non_unique_events_for_person: (people) ->
    bb.try( -> [])

  get_active_things: ->
    #Select 10K events, count frequencies order them and return
    @_r.table("#{@namespace}_events", {useOutdated: true}).sample(10000)
    .group('thing')
    .count()
    .ungroup()
    .orderBy(@_r.desc('reduction'))
    .limit(100)('group').run({useOutdated: true})

  get_active_people: ->
    #Select 10K events, count frequencies order them and return
    @_r.table("#{@namespace}_events", {useOutdated: true}).sample(10000)
    .group('person')
    .count()
    .ungroup()
    .orderBy(@_r.desc('reduction'))
    .limit(100)('group').run({useOutdated: true})

  compact_people : (compact_database_person_action_limit) ->
    @get_active_people()
    .then( (people) =>
      @truncate_people_per_action(people, compact_database_person_action_limit)
    )

  compact_things :  (compact_database_thing_action_limit) ->
    @get_active_things()
    .then( (things) =>
      @truncate_things_per_action(things, compact_database_thing_action_limit)
    )

  truncate_things_per_action: (things, trunc_size) ->

    #TODO do the same thing for things
    return bb.try( -> []) if things.length == 0
    @get_actions()
    .then((action_weights) =>
      return [] if action_weights.length == 0
      actions = (aw.key for aw in action_weights)
      #cut each action down to size
      promises = []
      for thing in things
        for action in actions
          promises.push @_r.table("#{@namespace}_events").getAll([action,thing], {index: "action_thing"}).orderBy(@_r.desc("created_at")).skip(trunc_size).delete().run({useOutdated: true, durability: "soft"})

      bb.all(promises)
    )

  truncate_people_per_action: (people, trunc_size) ->
    #TODO do the same thing for things
    return bb.try( -> []) if people.length == 0
    @get_actions()
    .then((action_weights) =>
      return bb.try(-> []) if action_weights.length == 0
      actions = (aw.key for aw in action_weights)
      promises = []
      for person in people
        for action in actions
          promises.push @_r.table("#{@namespace}_events").getAll([person, action],{index: "person_action"}).orderBy(@_r.desc("created_at")).skip(trunc_size).delete().run({useOutdated: true,durability: "soft"})
      #cut each action down to size
      bb.all(promises)
    )

  remove_events_till_size: (number_of_events) ->
    #TODO move too offset method
    #removes old events till there is only number_of_events left
    @_r.table("#{@namespace}_events").orderBy({index: @_r.desc("created_at")})
    .skip(number_of_events).delete().run({useOutdated: true,durability: "soft"})


module.exports = EventStoreMapper;
