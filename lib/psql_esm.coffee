q = require 'q'


init_events_table = (knex, schema) ->
  knex.schema.createTable("#{schema}.events",(table) ->
    table.increments();
    table.string('person').index().notNullable()
    table.string('action').index().notNullable()
    table.string('thing').index().notNullable()
    table.timestamps();
  )
  

init_action_table = (knex, schema) ->
  knex.schema.createTable("#{schema}.actions",(table) ->
    table.increments();
    table.string('action').unique().index().notNullable()
    table.integer('weight').notNullable()
    table.timestamps();
  )

#CLASS ACTIONS
drop_tables = (knex, schema = 'public') ->
  q.all( [
    knex.schema.dropTableIfExists("#{schema}.events"),
    knex.schema.dropTableIfExists("#{schema}.actions")
  ])

init_tables = (knex, schema = 'public') ->
  q.when(knex.schema.raw("CREATE SCHEMA IF NOT EXISTS #{schema}"))
  .then( => q.all([init_events_table(knex, schema), init_action_table(knex, schema)]))

class EventStoreMapper
  
  #INSTANCE ACTIONS
  constructor: (@knex, @schema = 'public') ->

  drop_tables: ->
    drop_tables(@knex,@schema)

  init_tables: ->
    init_tables(@knex,@schema)

  add_event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_event_to_db(person, action, thing)
    ])

  add_action: (action) ->
    @set_action_weight(action, 1, false)

  add_event_to_db: (person, action, thing) ->
    now = new Date().toISOString()
    @knex("#{@schema}.events").insert({person: person, action: action, thing: thing , created_at: now, updated_at: now})

  set_action_weight: (action, weight, overwrite = true) ->
    now = new Date().toISOString()
    #TODO change to atomic update or insert (upsert), because this can cause a race condition if you try add the same action multiple times, hence the catch -- graham
    
    insert = @knex("#{@schema}.actions").insert({action: action, weight: weight, created_at: now, updated_at: now}).toString()
    #bug described here http://stackoverflow.com/questions/15840922/where-not-exists-in-postgresql-gives-syntax-error
    insert = insert.replace(/\svalues\s\(/, " select ")[..-2]

    update_attr = {action: action}
    update_attr["weight"] = weight if overwrite
    update = @knex("#{@schema}.actions").where(action: action).update(update_attr).toString()

    #defined here http://www.the-art-of-web.com/sql/upsert/
    query = "BEGIN; LOCK TABLE #{@schema}.actions IN SHARE ROW EXCLUSIVE MODE; WITH upsert AS (#{update} RETURNING *) #{insert} WHERE NOT EXISTS (SELECT * FROM upsert); COMMIT;"
    @knex.raw(query)
    

  
  events_for_people_action_things: (people, action, things) ->
    return q.fcall(->[]) if people.length == 0 || things.length == 0
    @knex("#{@schema}.events").where(action: action).whereIn('person', people).whereIn('thing', things)

  has_person_actioned_thing: (person, action, thing) ->
    @has_event(person,action,thing)

  get_actions_of_person_thing_with_weights: (person, thing) ->
    @knex("#{@schema}.events").select("#{@schema}.events.action as key", "#{@schema}.actions.weight").leftJoin("#{@schema}.actions", "#{@schema}.events.action", "#{@schema}.actions.action").where(person: person, thing: thing).orderBy('weight', 'desc')

  get_ordered_action_set_with_weights: ->
    @knex("#{@schema}.actions").select('action as key', 'weight').orderBy('weight', 'desc')

    
  get_action_weight: (action) ->
    @knex("#{@schema}.actions").select('weight').where(action: action)
    .then((rows)->
      parseInt(rows[0].weight)
    )

  get_things_that_actioned_people: (people, action) =>
    return q.fcall(->[]) if people.length == 0
    @knex("#{@schema}.events").select('thing', 'created_at').where(action: action).whereIn('person', people).orderBy('created_at', 'desc')
    .then( (rows) ->
      (r.thing for r in rows)
    )

  get_people_that_actioned_things: (things, action) =>
    return q.fcall(->[]) if things.length == 0
    @knex("#{@schema}.events").select('person', 'created_at').where(action: action).whereIn('thing', things).orderBy('created_at', 'desc')
    .then( (rows) ->
      (r.person for r in rows)
    )

  get_things_that_actioned_person: (person, action) =>
    @knex("#{@schema}.events").select('thing', 'created_at').where(person: person, action: action).orderBy('created_at', 'desc')
    .then( (rows) ->
      (r.thing for r in rows)
    )

  get_people_that_actioned_thing: (thing, action) =>
    @knex("#{@schema}.events").select('person', 'created_at').where(thing: thing, action: action).orderBy('created_at', 'desc')
    .then( (rows) ->
      (r.person for r in rows)
    )

  things_people_have_actioned: (action, people) ->
    @knex("#{@schema}.events").select('thing', 'created_at').where(action: action).whereIn('person', people).orderBy('created_at', 'desc')
    .then( (rows) ->
      (r.thing for r in rows)
    )

  things_jaccard_metric: (thing1, thing2, action) ->
    q1 = @knex("#{@schema}.events").select('person').distinct().where(thing: thing1, action: action).toString()
    q2 = @knex("#{@schema}.events").select('person').distinct().where(thing: thing2, action: action).toString()

    intersection = @knex.raw("#{q1} INTERSECT #{q2}")
    union = @knex.raw("#{q1} UNION #{q2}")
    q.all([intersection, union])
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
    q.all([intersection, union])
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


EventStoreMapper.drop_tables = drop_tables
EventStoreMapper.init_tables = init_tables

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return EventStoreMapper)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = EventStoreMapper;
