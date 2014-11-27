bb = require 'bluebird'
_ = require 'underscore'

moment = require "moment"

#The only stateful things in GER are the ESM and the options 
class GER

  constructor: (@esm, options = {}) ->
    @set_options(options)

  set_options: (options) ->
    options = _.defaults(options,
      minimum_history_limit: 1,
      similar_people_limit: 25,
      related_things_limit: 10
      recommendations_limit: 20,
      recent_event_days: 14,
      previous_actions_filter: []
      compact_database_person_action_limit: 1500
      compact_database_thing_action_limit: 1500
      person_history_limit: 500
    )

    @minimum_history_limit = options.minimum_history_limit;
    @similar_people_limit = options.similar_people_limit
    @previous_actions_filter = options.previous_actions_filter
    @recommendations_limit = options.recommendations_limit
    @related_things_limit = options.related_things_limit

    @compact_database_person_action_limit = options.compact_database_person_action_limit

    @compact_database_thing_action_limit = options.compact_database_thing_action_limit

    @recent_event_days = options.recent_event_days
    @person_history_limit = options.person_history_limit

  related_people: (object, actions, action) ->
    #split actions in 2 by weight
    #call twice
    action_list = Object.keys(actions)
    [ltmean, gtmean] = @half_array_by_mean(action_list, actions)

    bb.all([
      @esm.get_related_people(object, ltmean, action, @similar_people_limit, @person_history_limit), 
      @esm.get_related_people(object, gtmean, action, @similar_people_limit, @person_history_limit)])
    .spread( (ltpeople, gtpeople) ->
      _.unique(ltpeople.concat gtpeople)
    )
  ####################### Weighted people  #################################
  combine_weights_with_actions: (object_weights, actions, total_action_weight) ->
    # join the weights together
    temp = {}
    for p, weights of object_weights
      for ac, weight of weights
        temp[p] = 0 if p not of temp
        temp[p] += weight * (actions[ac] / total_action_weight) # jaccard weight for action * percent of 
    
    temp    

  weight_people : (person, people, actions) ->
    total_action_weight = 0
    for action, weight of actions
      total_action_weight += weight

    #TODO fix this, it double counts newer listings [now-recentdate] then [now-limit] should be [now-recentdate] then [recentdate-limit]
    @esm.get_jaccard_distances_between_people(person, people, Object.keys(actions), @person_history_limit, @recent_event_days)
    .spread( (event_weights, recent_event_weights) =>
      [
        @combine_weights_with_actions(event_weights, actions, total_action_weight), 
        @combine_weights_with_actions(recent_event_weights, actions, total_action_weight)
      ]
    )
    .spread( (event_weights, recent_event_weights) =>
      # join the weights together
      temp = {}
      temp[person] = 1
      #These weights start at a rate of 2:1 so to get to 80:20 we need 4:1*2:1 this could be wrong -- graham
      for p, w of event_weights
        temp[p] = ((recent_event_weights[p] * 4) + (event_weights[p] * 1))/5.0
      
      temp
    )

  weighted_similar_people: (object, action) ->
    @esm.get_ordered_action_set_with_weights()
    .then( (action_weights) =>
      actions = {}
      (actions[aw.key] = aw.weight for aw in action_weights when aw.weight > 0)
      bb.all([actions, @related_people(object, actions, action)])
    )
    .spread( (actions, objects) =>
      @weight_people(object, objects, actions)
    )
    .then( (people_weights) =>
      # add confidence to the selection

      # Weight the list of subjects by looking for the probability they are actioned by the similar objects

      total_weight = 0
      for p, weight of people_weights
        total_weight += weight if p != object #remove object as it is 1

      n_people = Object.keys(people_weights).length - 1 #remove original object

      {
        people_weights: people_weights,
        n_people: n_people
      }
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
  
  filter_recommendations: (person, recommendations) ->
    @esm.filter_things_by_previous_actions(person, Object.keys(recommendations), @previous_actions_filter)
    .then( (filter_things) ->
      ({thing: thing, weight: weight_date.weight, last_actioned_at: weight_date.last_actioned_at} for thing, weight_date of recommendations when thing in filter_things)
    )

  people_confidence: (n_people ) ->
    #The more similar people found, the more we trust the recommendations
    #15 is a magic number chosen to make 10 around 50% and 50 around 95%
    pc = 1.0 - Math.pow(Math.E,( (- n_people) / 15 ))
    #The person confidence multiplied by the mean distance
    pc

  history_confidence: (n_history) ->
    # The more hisotry (input) the more we trust the recommendations
    # 35 is a magic number to make 100 about 100%
    hc = 1.0 - Math.pow(Math.E,( (- n_history) / 35 ))
    hc

  things_confidence: (recommendations) ->
    return 0 if recommendations.length == 0
    # The greater the mean recommendation the more we trust the recommendations
    # 2 is a magic number to make 10 about 100%
    total_weight = 0
    for r in recommendations
      total_weight += r.weight

    mean_weight = total_weight/recommendations.length
    tc = 1.0 - Math.pow(Math.E,( (- mean_weight) / 2 ))

    tc

  generate_recommendations_for_person: (person, action, person_history_count = 1) ->
    @weighted_similar_people(person, action)
    .then( (similar_people) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      bb.all([
        similar_people, 
        @get_things_for_person(action, similar_people.people_weights)
      ])
    )
    .spread( ( similar_people, people_things ) =>
      people_weights = similar_people.people_weights
      things_weight = {}
      for p, things of people_things
        for thing_date in things
          thing = thing_date.thing
          last_actioned_at = thing_date.last_actioned_at

          things_weight[thing] = {weight: 0} if things_weight[thing] == undefined
          things_weight[thing].weight += people_weights[p]
          if things_weight[thing].last_actioned_at == undefined or things_weight[thing].last_actioned_at < last_actioned_at
            things_weight[thing].last_actioned_at = last_actioned_at 
             
          

      # CALCULATE CONFIDENCES
      bb.all([@filter_recommendations(person, things_weight), similar_people] )
    )
    .spread( (recommendations, similar_people) =>

      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      sorted_things = recommendations.sort((x, y) -> y.weight - x.weight)
      sorted_things = sorted_things[0...@recommendations_limit]
      
      people_confidence = @people_confidence(similar_people.n_people)
      history_confidence = @history_confidence(person_history_count)
      things_confidence = @things_confidence(sorted_things)

      confidence = people_confidence * history_confidence * things_confidence
      {recommendations: sorted_things, confidence: confidence}
    )

  recommendations_for_person: (person, action) ->
    #first a check or two
    @esm.person_thing_history_count(person)
    .then( (count) =>
      if count < @minimum_history_limit
        return {recommendations: [], confidence: 0}
      else
        return @generate_recommendations_for_person(person, action, count)
    )

  ##Wrappers of the ESM

  count_events: ->
    @esm.count_events()

  estimate_event_count: ->
    @esm.estimate_event_count()

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

  compact_people : () ->
    @esm.get_active_people()
    .then( (people) =>
      @esm.remove_non_unique_events_for_people(people)
      .then( =>
        #remove events per (active) person action that exceed some number
        @esm.truncate_people_per_action(people, @compact_database_person_action_limit)
      )
    )

  compact_things :  () ->
    @esm.get_active_things()
    .then( (things) =>
      @esm.truncate_things_per_action(things, @compact_database_thing_action_limit)
    )

  compact_database: ->
    @esm.analyze()
    .then( =>
      promises = []
      promises.push @esm.remove_expired_events()
      promises.push @compact_people()
      promises.push @compact_things()
      bb.all(promises)
    )
    .then( =>
      @esm.analyze()
    )

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


