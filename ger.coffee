bb = require 'bluebird'
_ = require 'underscore'

class GER

  constructor: (@esm, options = {}) ->
    options = _.defaults(options, 
      similar_people_limit: 100,
      related_things_limit: 1000
      recommendations_limit: 20,
      previous_actions_filter: []
      compact_database_person_action_limit: 3000
    )

    @similar_people_limit = options.similar_people_limit
    @previous_actions_filter = options.previous_actions_filter
    @recommendations_limit = options.recommendations_limit
    @related_things_limit = options.related_things_limit

    @compact_database_person_action_limit = options.compact_database_person_action_limit

  related_people: (object, actions, action) ->
    #split actions in 2 by weight
    #call twice
    action_list = Object.keys(actions)
    [ltmean, gtmean] = @half_array_by_mean(action_list, actions)

    bb.all([
      @esm.get_related_people(object, ltmean, action, @similar_people_limit), 
      @esm.get_related_people(object, gtmean, action, @similar_people_limit)])
    .spread( (ltpeople, gtpeople) ->
      _.unique(ltpeople.concat gtpeople)
    )
  ####################### Weighted people  #################################

  weighted_similar_people: (object, action) ->
    @esm.get_ordered_action_set_with_weights()
    .then( (action_weights) =>
      actions = {}
      (actions[aw.key] = aw.weight for aw in action_weights when aw.weight > 0)
      bb.all([actions, @related_people(object, actions, action)])
    )
    .spread( (actions, objects) =>
      bb.all([actions, @esm.get_jaccard_distances_between_people(object, objects, Object.keys(actions))])
    )
    .spread( (actions, object_weights) =>
      # join the weights together
      total_weight = 0
      for action, weight of actions
        total_weight += weight

      temp = {}
      temp[object] = 1 #manually add the object
      for p, weights of object_weights
        for ac, weight of weights
          temp[p] = 0 if p not of temp
          temp[p] += weight/total_weight * actions[ac]
      temp
    )

  half_array_by_mean: (arr, weights) ->
    total_weight = _.reduce((weights[p] for p in arr), ((a,b) -> a+b) , 0)
    mean_weigth = total_weight/arr.length
    [ltmean, gtmean] = _.partition(arr, (p) -> weights[p] < mean_weigth)
    [ltmean, gtmean]

  get_things_for_person: (action, people_weights) ->
    people_list = Object.keys(people_weights)
    
    [ltmean, gtmean] = @half_array_by_mean(people_list, people_weights)
    bb.all([
      @esm.things_people_have_actioned(action, ltmean, @related_things_limit), 
      @esm.things_people_have_actioned(action, gtmean, @related_things_limit)
    ])
    .spread( (t1, t2) ->
      _.extend(t1, t2)
    )
    
  recommendations_for_person: (person, action) ->
    #recommendations for object action from similar people
    #recommendations for object action from object, only looking at what they have already done
    #then join the two objects and sort
    @weighted_similar_people(person, action)
    .then( (people_weights) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      bb.all([people_weights, @get_things_for_person(action, people_weights)])
    )
    .spread( ( people_weights, people_things) =>
      # Weight the list of subjects by looking for the probability they are actioned by the similar objects
      total_weight = 0
      for p, weight of people_weights
        total_weight += weight

      #TODO total weight = 0
      things_weight = {}
      for p, things of people_things
        for thing in things
          things_weight[thing] = 0 if things_weight[thing] == undefined
          things_weight[thing] += people_weights[p]

      if total_weight != 0
        for thing, weight of things_weight
          things_weight[thing] = weight/total_weight 

      things_weight
    )
    .then( (recommendations) =>
      bb.all([recommendations, @esm.filter_things_by_previous_actions(person, Object.keys(recommendations), @previous_actions_filter)])
    )
    .spread( (recommendations, filter_things) =>

      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      weight_things = ({thing: thing, weight: weight} for thing, weight of recommendations when thing in filter_things)
      sorted_things = weight_things.sort((x, y) -> y.weight - x.weight)

      sorted_things = sorted_things[0...@recommendations_limit]
      sorted_things
    ) 

  ##Wrappers of the ESM

  count_events: ->
    @esm.count_events()

  event: (person, action, thing, dates = {}) ->
    @esm.add_event(person,action, thing, dates)
    .then( -> {person: person, action: action, thing: thing})

  action: (action, weight=1, override = true) ->
    @esm.set_action_weight(action, weight, override)
    .then( -> {action: action, weight: weight}) 

  find_event: (person, action, thing) ->
    @esm.find_event(person, action, thing)

  get_action:(action) ->
    @esm.get_action_weight(action)
    .then( (weight) -> 
      return null if weight == null
      {action: action, weight: weight}
    )

  bootstrap: (stream) ->
    #filename should be person, action, thing, created_at, expires_at
    #this will require manually adding the actions
    @esm.bootstrap(stream)
    

  #  DATABASE CLEANING #

  compact_database: ->
    @esm.vacuum_analyze()
    .then( => @esm.get_active_people())
    .then( (people) => 
      promises = []
      #remove expired events
      promises.push @esm.remove_expired_events()

      #remove events per (active) person action that exceed some number
      promises.push @esm.truncate_people_per_action(people, @compact_database_person_action_limit)

      #TODO remove non_unique events for active people
      bb.all(promises)
    )
    .then(=> @esm.vacuum_analyze())

  compact_database_to_size: (number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    @esm.remove_events_till_size(number_of_events)


RET = {}

RET.GER = GER

knex = require 'knex'
RET.knex = knex

RET.PsqlESM = require('./lib/psql_esm')

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


