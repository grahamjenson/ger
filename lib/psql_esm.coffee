q = require 'q'

#create the actions table if it doesn't already exist
#action | weight

#create the events table if it doesn't already exist
# person, action, thing, created_at

#connect to database




#Create postgres store wrapper

class EventStoreMapper

  constructor: (@knex) ->

  init_database_tables: ->
    q.all([@init_events_table(), @init_action_table()])

  init_events_table: ->
    @knex.schema.hasTable('events')
    .then( (has_events_table) =>
      if has_events_table 
        true
      else
        @knex.schema.createTable('events',(table) ->
          table.increments();
          table.string('person').index().notNullable()
          table.string('action').index().notNullable()
          table.string('thing').index().notNullable()
          table.timestamps();
        )
    )

  init_action_table: ->
    @knex.schema.hasTable('actions')
    .then( (has_actions_table) =>
      if has_actions_table 
        true
      else
        @knex.schema.createTable('actions',(table) ->
          table.increments();
          table.string('action').unique().index().notNullable()
          table.integer('weight').notNullable()
          table.timestamps();
        )
    )

  add_event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_event_to_db(person, action, thing)
      ])

  add_action: (action) ->
    @set_action_weight(action, 1, false)

  add_event_to_db: (person, action, thing) ->
    now = new Date().toISOString()
    @knex('events').insert({person: person, action: action, thing: thing , created_at: now, updated_at: now})

  set_action_weight: (action, weight, overwrite = true) ->
    now = new Date().toISOString()
    #TODO change to atomic update or insert (upsert), because this can cause a race condition if you try add the same action multiple times, hence the catch -- graham
    @knex('actions').where(action: action).count()
    .then( (count) =>
      count = parseInt(count[0].count)
      if count == 0
        @knex('actions').insert({action: action, weight: weight, created_at: now, updated_at: now})
      else
        @knex('actions').where(action: action).update({weight: weight}) if overwrite
    )
    .catch( (error) ->
      #error code 23505 is unique key violation
      if error.code != '23505'
        throw error
    )
    

     
  has_person_actioned_thing: (person, action, thing) ->
    @has_event(person,action,thing)

  
  get_actions_of_person_thing_with_weights: (person, thing) ->
    @knex('events').select('events.action as key', 'actions.weight').leftJoin('actions', 'events.action', 'actions.action').where(person: person, thing: thing).orderBy('weight', 'desc')
    
  get_action_set: ->
    @knex('actions').select('action')
    .then( (rows) ->
      (r.action for r in rows)
    )

  get_action_set_with_weights: ->
    @knex('actions').select('action as key', 'weight').orderBy('weight', 'desc')

    
  get_action_weight: (action) ->
    @knex('actions').select('weight').where(action: action)
    .then((rows)->
      parseInt(rows[0].weight)
    )

  get_person_action_set: (person, action) =>
    @knex('events').select('thing').where(person: person, action: action)
    .then( (rows) ->
      (r.thing for r in rows)
    )

  get_thing_action_set: (thing, action) =>
    @knex('events').select('person').where(thing: thing, action: action)
    .then( (rows) ->
      (r.person for r in rows)
    )

  things_people_have_actioned: (action, people) ->
    @knex('events').select('thing').distinct().where(action: action).whereIn('person', people)
    .then( (rows) ->
      (r.thing for r in rows)
    )

  things_jaccard_metric: (thing1, thing2, action) ->
    q1 = @knex('events').select('person').distinct().where(thing: thing1, action: action).toString()
    q2 = @knex('events').select('person').distinct().where(thing: thing2, action: action).toString()

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
    q1 = @knex('events').select('thing').distinct().where(person: person1, action: action).toString()
    q2 = @knex('events').select('thing').distinct().where(person: person2, action: action).toString()

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
    @knex('events').where({person: person, action: action, thing: thing})
    .then( (rows) ->
      rows.length > 0
    )

  has_action: (action) ->
    @knex('actions').where(action: action)
    .then( (rows) ->
      rows.length > 0
    )

  count_events: ->
    @knex('events').count()
    .then (count) -> parseInt(count[0].count)

  count_actions: ->
    @knex('actions').count()
    .then (count) -> parseInt(count[0].count)

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return EventStoreMapper)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = EventStoreMapper;
