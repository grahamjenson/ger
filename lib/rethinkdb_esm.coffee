bb = require 'bluebird'
fs = require 'fs'
crypto = require 'crypto'
moment = require 'moment'
shasum = null
is_changefeed_enabled = false;
Transform = require('stream').Transform

class CounterStream extends Transform
  _transform: (chunk, encoding, done) ->
    @count |= 0
    for ch in chunk
      @count += 1 if ch == 10
    @push(chunk)
    done()

#CLASS ACTIONS
drop_tables = (r) ->
  true
  #promises = []
  #r.tableList().run().then((list) ->
  #    ["events","actions","most_common_things","most_common_people"].forEach (t) ->
  #        if(list.indexOf t is -1)
  #            promises.push(r.tableDrop(t).run().error((err) -> console.log(err)))
  #    bb.all(promises)
  #)

init_changefeed = (r) ->
  bb.try(=>
    is_changefeed_enabled = true
    r.table("events").changes().run().then((feed) =>
      feed.each((err, change) =>
        if !err
          if (change.old_val is null and change.new_val isnt null)
            #insert
            hash = crypto.createHash("sha256")
            hash.update(change.new_val.person.toString())
            person_id = hash.digest("hex")
            r.table("most_common_people").get(person_id).replace((doc) ->
              doc.default({
                id: person_id,
                person: change.new_val.person,
                count: 0
              }).merge((valid_doc) ->
                {
                  count: valid_doc("count").add(1)
                }
              )
            ).run({
              durability: "soft",
              noreply: true
            })
            hash = crypto.createHash("sha256")
            hash.update(change.new_val.thing.toString())
            thing_id = hash.digest("hex")
            r.table("most_common_things").get(thing_id).replace((doc) ->
              doc.default({
                id: thing_id,
                thing: change.new_val.thing,
                count: 0
              }).merge((valid_doc) ->
                {
                  count: valid_doc("count").add(1)
                }
              )
            ).run({
              durability: "soft",
              noreply: true
            })
          else if (change.new_val is null)
            #delete
            hash = crypto.createHash("sha256")
            hash.update(change.old_val.person.toString())
            person_id = hash.digest("hex")
            r.table("most_common_people").get(person_id).replace((doc) =>
              doc.default({
                id: person_id,
                person: change.old_val.person,
                count: 1
              }).merge((valid_doc) =>
                {
                  count: r.branch(valid_doc("count").gt(0),valid_doc("count").sub(1),0)
                }
              )
            ).run({
              durability: "soft",
              noreply: true
            })
            hash = crypto.createHash("sha256")
            hash.update(change.old_val.thing.toString())
            thing_id = hash.digest("hex")
            r.table("most_common_things").get(thing_id).replace((doc) =>
              doc.default({
                id: thing_id,
                thing: change.old_val.thing,
                count: 1
              }).merge((valid_doc) =>
                {
                  count: r.branch(valid_doc("count").gt(0),valid_doc("count").sub(1),0)
                }
              )
            ).run({
              durability: "soft",
              noreply: true
            })
      )
    )
  )

clear_tables = (r) ->
  r.table("most_common_things").delete().run().then =>
    r.table("most_common_people").delete().run().then =>
      r.table("events").delete().run().then =>
        r.table("actions").delete().run().then =>
          init_changefeed(r) if not is_changefeed_enabled


init_tables = (r) ->
  r.tableList().run().then (list) ->
    if list.length > 0
      bb.try -> clear_tables(r)
    else
      bb.all([
        r.tableCreate("most_common_things").run(),
        r.tableCreate("most_common_people").run(),
        r.tableCreate("events").run(),
        r.tableCreate("actions").run(),
      ]).then(->
        bb.join([
            r.table("actions").indexCreate("weight").run(),
            r.table("most_common_things").indexCreate("count").run(),
            r.table("most_common_people").indexCreate("count").run(),
            r.table("events").indexCreate("created_at").run(),
            r.table("events").indexCreate("expires_at").run(),
            r.table("events").indexCreate("person").run(),
            r.table("events").indexCreate("action_thing",[r.row("action"),r.row("thing")]).run(),
            r.table("events").indexCreate("person_action",[r.row("person"),r.row("action")]).run(),
            r.table("events").indexCreate("person_action_created_at",[r.row("person"),r.row("action"),r.row("created_at")]).run(),
            r.table("events").indexCreate("thing").run(),
            r.table("actions").indexWait("weight").run(),
            r.table("most_common_things").indexWait("count").run(),
            r.table("most_common_people").indexWait("count").run(),
            r.table("events").indexWait(["created_at","expires_at","person","action_thing","person_action","person_action_created_at","thing"]).run(),
            init_changefeed(r)
        ])
      )

#The only stateful thing in this ESM is the UUID (schema), it should not be changed

class EventStoreMapper

  type: "rethinkdb"

  invalidate_action_cache: ->
    @action_cache = null

  #INSTANCE ACTIONS
  constructor: (schema, orms) ->
    @_r = orms.r
    @action_cache = null

  destroy: ->
    drop_tables(@_r)

  initialize: ->
    init_tables(@_r)

  clear_tables: ->
    clear_tables(@_r)

  analyze: ->
    bb.try(-> true)

  vacuum_analyze: ->
    bb.try(-> true)

  add_event: (person, action, thing, dates = {}) ->
    expires_at = dates.expires_at
    if dates.created_at
      if dates.created_at._isAMomentObject
        dates.created_at = dates.created_at.format()
      date = moment(dates.created_at, moment.ISO_8601);
      if(date.isValid())
        created_at = @_r.ISO8601(dates.created_at)
      else
        created_at = @_r.ISO8601(dates.created_at.toISOString())
    else
        created_at = @_r.ISO8601(new Date().toISOString())
    if dates.expires_at
      if dates.expires_at._isAMomentObject
        dates.expires_at = dates.expires_at.format()
      date = moment(dates.expires_at, moment.ISO_8601);
      if(date.isValid())
        expires_at = @_r.ISO8601(dates.expires_at)
      else
        expires_at = @_r.ISO8601(dates.expires_at.toISOString())
    else
      expires_at = null
    @add_event_to_db(person, action, thing, created_at, expires_at)

  upsert: (table, insert_attr, identity_attr,overwrite = true) ->
    if overwrite
      conflict_method = "update"
    else
      conflict_method = "error"
    shasum = crypto.createHash("sha256")
    shasum.update(identity_attr.toString())
    insert_attr.id = shasum.digest("hex")
    @_r.table(table).insert(insert_attr, {conflict: conflict_method}).run({ durability: "soft" })

  find_event: (person, action, thing) ->
    shasum = crypto.createHash("sha256")
    shasum.update(person.toString() + action + thing)
    id = shasum.digest("hex")
    @_r.table("events").get(id).without("id").default(null).run()

  add_event_to_db: (person, action, thing, created_at, expires_at = null) ->
    insert_attr = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
    identity_attr = person + action + thing
    @upsert("events", insert_attr, identity_attr)

  set_action_weight: (action, weight, overwrite = true) ->
    @invalidate_action_cache()
    now = new Date()
    insert_attr =  {action: action, weight: +weight, created_at: now, updated_at: now}
    identity_attr = action
    @upsert("actions", insert_attr, identity_attr,overwrite)

  person_history_count: (person) ->
    @_r.table("events").getAll(person,{index: "person"})("thing")
    .default([]).distinct().count().run()

  get_ordered_action_set_with_weights: ->
    return bb.try( => @action_cache) if @action_cache
    bb.try =>
        @_r.table("actions").orderBy({index: @_r.desc("weight")})
        .map((row) => {key: row("action"), weight: row('weight')}).run()
        .then( (rows) =>
          @action_cache = rows
          rows
        )

  get_actions: ->
    return bb.try( => @action_cache) if @action_cache
    @_r.table("actions").orderBy({index: @_r.desc("weight")})
    .map((row) ->
      return {
        key: row("action"),
        weight: row("weight")
      }
    )
    .run()
    .then( (rows) =>
      @action_cache = rows
      rows
    )

  get_action_weight: (action) ->
    shasum = crypto.createHash("sha256")
    shasum.update(action.toString())
    id = shasum.digest("hex")
    @_r.table("actions").get(id)('weight').default(null).run()

  find_similar_people: (person, actions, action, limit = 100, search_limit = 500) ->
    return bb.try(-> []) if !actions or actions.length == 0
    @_r.table("events").getAll(person,{index: "person"})
    .pluck("person", "action", "thing", "created_at")
    .orderBy(@_r.desc('created_at'))
    .limit(search_limit)
    .eqJoin([@_r.row("action"),@_r.row("thing")],r.table("events"),{index: "action_thing"})
    .filter((row) =>
        row("right")("person").ne(row("left")("person")).and(@_r.expr(actions).contains(row("right")("action")))
    )
    .pluck({
        left: ["created_at"],
        right: true
    })
    .zip()
    .group("person")
    .map((row) ->
        {
            created_at: row("created_at"),
            count: 1
        }
    )
    .reduce((a,b) =>
        {
            created_at: @_r.expr([a("created_at"),b("created_at")]).max(),
            count: a("count").add(b("count"))
        }
    )
    .ungroup().map((row) ->
        {
            created_at_day: row("reduction")("created_at").day(),
            count: row("reduction")("count"),
            person: row("group")
        }
    ).orderBy(@_r.desc("created_at_day"),@_r.desc("count"))
    .eqJoin([@_r.row("person"),action],@_r.table("events"),{index: "person_action"})
    .pluck({left: true}).zip().limit(limit)("person").default([]).run()

  filter_things_by_previous_actions: (person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0
    indexes = []
    indexes.push([person, action]) for action in actions
    @_r.expr(things).setDifference(@_r.table("events").getAll(@_r.args(indexes),{index: "person_action"})
    .coerceTo("ARRAY")("thing")).run()

  recently_actioned_things_by_people: (action, people, limit = 50) ->
    return bb.try(->[]) if people.length == 0

    indexes = []
    for p in people
      indexes.push([p,action])

    @_r.table("events").getAll(@_r.args(indexes),{index: "person_action"})
    .group("person","thing").max("created_at").ungroup().limit(limit)
    .group((row) ->
      row("group").nth(0)
    ).ungroup()
    .map((row) =>
      @_r.object(row("group").coerceTo("string"),
        row("reduction").map((row) ->
          {
            thing: row("group").nth(1),
            last_actioned_at: row("reduction")("created_at").toEpochTime()
          }
        )
      )
    )
    .reduce((a,b) =>
        a.merge(b)
    ).default({})
    .run()

  get_jaccard_distances_between_people: (person, people, actions, limit = 500, days_ago=14) ->
    return bb.try(->[]) if people.length == 0
    #TODO allow for arbitrary distance measurements here

    bb.try =>
        flat_people_actions = []
        people_actions = ([p, a] for a in actions for p in people)
        flat_people_actions = flat_people_actions.concat.apply(flat_people_actions, people_actions)
        person_actions = []
        for a in actions
            person_actions.push [person, a]

        query = @_r.table("events").getAll(@_r.args(flat_people_actions), {index: "person_action"})
        .group("person","action").ungroup()
        .map((row) ->
            {
                person: row("group").nth(0),
                action: row("group").nth(1),
                things: row("reduction").pluck("created_at","thing")
            }
        )
        .map((row) =>
            people_things = row("things")("thing").distinct().coerceTo("ARRAY")
            people_recent_things = row("things").filter((row2) =>
                row2("created_at").gt(@_r.now().sub(days_ago * 24 * 60 * 60))
            )("thing").coerceTo("ARRAY")
            person_data = @_r.table("events").getAll([person, row("action")], {index: "person_action"})
            .group("thing").ungroup().coerceTo("ARRAY")
            person_recent_things = person_data.filter((row2) =>
                row2("reduction")("created_at").gt(@_r.now().sub(days_ago * 24 * 60 * 60))
            ).map((row2) ->
                row2("reduction")("thing")
            ).coerceTo("ARRAY")
            person_things = person_data.map((row2) ->
                row2("group")
            ).coerceTo("ARRAY")
            intersection = @_r.expr(people_things).setIntersection(person_things).count()
            union = people_things.union(person_things).distinct().count()
            intersection_recent = @_r.expr(people_recent_things).setIntersection(person_recent_things).count()
            union_recent = people_recent_things.union(person_recent_things).distinct().count()
            return {
                person: row("person"),
                action: row("action"),
                things: people_things,
                limit_distance: intersection.div(@_r.branch(r.expr(union).gt(0), union, 1)),
                recent_distance: intersection_recent.div(@_r.branch(r.expr(union_recent).gt(0), union_recent, 1)),
            }
        )
        query.run().then( (rows) ->
          limit_distance = {}
          recent_distance = {}
          for row in rows
            recent_distance[row["person"]] ||= {}
            limit_distance[row["person"]] ||= {}

            limit_distance[row["person"]][row["action"]] = row["limit_distance"]
            recent_distance[row["person"]][row["action"]] = row["recent_distance"]

          [limit_distance, recent_distance]
        )

  calculate_similarities_from_person: (person, people, actions, person_history_limit, recent_event_days) ->
    #TODO fix this, it double counts newer listings [now-recentdate] then [now-limit] should be [now-recentdate] then [recentdate-limit]
    @get_jaccard_distances_between_people(person, people, actions, person_history_limit, recent_event_days)
    .spread( (event_weights, recent_event_weights) =>
      temp = {}
      #These weights start at a rate of 2:1 so to get to 80:20 we need 4:1*2:1 this could be wrong -- graham
      for p in people
        temp[p] = {}
        for ac in actions
          temp[p][ac] = ((recent_event_weights[p][ac] * 4) + (event_weights[p][ac] * 1))/5.0

      temp
    )

  has_event: (person, action, thing) ->
    shasum = crypto.createHash("sha256")
    shasum.update(person.toString() + action + thing)
    id = shasum.digest("hex")
    @_r.table("events").get(id).ne(null).run()

  has_action: (action) ->
    shasum = crypto.createHash("sha256")
    shasum.update(action.toString())
    id = shasum.digest("hex")
    @_r.table("actions").get(id).ne(null).run()

  count_events: ->
    @_r.table("events").count().run()

  estimate_event_count: ->
    @_r.table("events").count().run()

  count_actions: ->
    @_r.table("actions").count().run()

  bootstrap: (stream) ->
    #stream of  person, action, thing, created_at, expires_at CSV
    #this will require manually adding the actions
    r_bulk = []
    deferred = bb.defer()
    counter = new CounterStream()
    stream.pipe(counter).on("data", (row) ->
        row = row.toString('utf-8').split("\n");
        for item in row
          data = item.split(",")
          if data.length > 1
            shasum = crypto.createHash("sha256")
            shasum.update(data[0] + data[1] + data[2])
            id = shasum.digest("hex")
            if data[4]
                expires_at = new Date(data[4])
            else
                expires_at = null
            r_bulk.push({
                id: id,
                person: data[0],
                action: data[1],
                thing: data[2],
                created_at: new Date(data[3]),
                expires_at: expires_at
            })
    ).on("end", =>
      if r_bulk.length > 0
        promises = []
        sub_bulk = []
        for item in r_bulk
          if sub_bulk.length < 50
            sub_bulk.push item
          else
            promises.push @_r.table("events").insert(sub_bulk,{conflict: "replace"}).run({durability: "soft"})
            sub_bulk = []
        if sub_bulk.length > 0
          promises.push @_r.table("events").insert(sub_bulk,{conflict: "replace"}).run({durability: "soft"})
        console.log(promises.length)
        bb.all(promises).then((result)-> deferred.resolve(counter.count))
      else
        deferred.resolve(counter.count)
    ).on('error', (error) -> deferred.reject(error))

    deferred.promise

  # DATABASE CLEANING METHODS

  expire_events: ->
    #removes the events passed their expiry date
    @_r.table("events").between(null,@_r.now(),{index: "expires_at",rightBound: "closed"}).delete().run()

  pre_compact: ->
    bb.try -> true

  post_compact: ->
    bb.try -> true

  remove_non_unique_events_for_people: (people) ->
    bb.try( -> [])

  remove_non_unique_events_for_person: (people) ->
    bb.try( -> [])

  #TODO refactor out useful methods
  get_active_things: ->
    #TODO WILL NOT WORK IF COMMA IN NAME
    #select most_common_vals from pg_stats where attname = 'thing';
    @_r.table('most_common_things').orderBy({index: @_r.desc("count")})("thing")
    .limit(100).default([]).run()

  get_active_people: ->
    #TODO WILL NOT WORK IF COMMA IN NAME
    #select most_common_vals from pg_stats where attname = 'person';
    @_r.table('most_common_people').orderBy({index: @_r.desc("count")})("person")
    .limit(100).default([]).run()

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
          promises.push @_r.table("events").getAll([action,thing], {index: "action_thing"}).orderBy(@_r.desc("created_at")).skip(trunc_size).delete().run()

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
          promises.push @_r.table("events").getAll([person, action],{index: "person_action"}).orderBy(@_r.desc("created_at")).skip(trunc_size).delete().run()
      #cut each action down to size
      bb.all(promises)
    )

  remove_events_till_size: (number_of_events) ->
    #TODO move too offset method
    #removes old events till there is only number_of_events left
    @_r.table("events").orderBy({index: @_r.desc("created_at")})
    .skip(number_of_events).delete().run()

EventStoreMapper.drop_tables = drop_tables
EventStoreMapper.init_tables = init_tables
EventStoreMapper.init_changefeed = init_changefeed
EventStoreMapper.clear_tables = clear_tables

module.exports = EventStoreMapper;
