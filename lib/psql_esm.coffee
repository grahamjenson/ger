q = require 'q'

#create the actions table if it doesn't already exist
#action | score

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
    #Add action if it does not already exist
    now = new Date().toISOString()
    @knex('actions').insert({action: action, weight: 1, created_at: now, updated_at: now})

  add_event_to_db: (person, action, thing) ->
    now = new Date().toISOString()
    @knex('events').insert({person: person, action: action, thing: thing , created_at: now, updated_at: now})

  set_action_weight: (action, score) ->


  things_people_have_actioned: (action, people) =>
    
  has_person_actioned_thing: (object, action, subject) ->
    
  get_actions_of_person_thing_with_scores: (person, thing) =>
    q.all([@store.set_members(KeyManager.person_thing_set_key(person, thing)), @get_action_set_with_scores()])
    .spread( (actions, action_scores) ->
      (as for as in action_scores when as.key in actions)
    )
    
  get_action_set: ->
    
  get_action_set_with_scores: ->


    
  get_action_weight: (action) ->
    
  get_person_action_set: (person, action) =>

  get_thing_action_set: (thing, action) =>


  things_jaccard_metric: (thing1, thing2, action_key) ->
    q.all([@store.set_intersection([s1,s2]), @store.set_union([s1,s2])])
    .spread((int_set, uni_set) -> 
      ret = int_set.length / uni_set.length
      if isNaN(ret)
        return 0
      return ret
    ) 

  people_jaccard_metric: (person1, person2, action_key) ->
    q.all([@store.set_intersection([s1,s2]), @store.set_union([s1,s2])])
    .spread((int_set, uni_set) -> 
      ret = int_set.length / uni_set.length
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
