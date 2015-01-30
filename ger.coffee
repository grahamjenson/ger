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
      crowd_weight: 0
    )

    @crowd_weight = options.crowd_weight
    @minimum_history_limit = options.minimum_history_limit;
    @similar_people_limit = options.similar_people_limit
    @previous_actions_filter = options.previous_actions_filter
    @recommendations_limit = options.recommendations_limit
    @related_things_limit = options.related_things_limit

    @compact_database_person_action_limit = options.compact_database_person_action_limit

    @compact_database_thing_action_limit = options.compact_database_thing_action_limit

    @recent_event_days = options.recent_event_days
    @person_history_limit = options.person_history_limit


  ####################### Weighted people  #################################

  calculate_similarities_from_person : (person, people, actions) ->
    @esm.calculate_similarities_from_person(person, people, Object.keys(actions), @person_history_limit, @recent_event_days)
    .then( (people_weights) =>
      temp = {}
      for p, weights of people_weights
        for ac, weight of weights
          temp[p] = 0 if p not of temp
          temp[p] += weight * actions[ac] # jaccard weight for action * percent of 
      temp[person] = 1 # add person 
      temp
    )
    .then( (people_weights) =>
      # add confidence to the selection

      # Weight the list of subjects by looking for the probability they are actioned by the similar objects

      total_weight = 0
      for p, weight of people_weights
        total_weight += weight if p != person #remove object as it is 1

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
    
  
  filter_recommendations: (person, recommendations) ->
    @esm.filter_things_by_previous_actions(person, Object.keys(recommendations), @previous_actions_filter)
    .then( (filter_things) ->
      filtered_recs = []
      for thing, recommendation_info of recommendations
        if thing in filter_things
          filtered_recs.push recommendation_info
      filtered_recs
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


  find_similar_people: (person, action, actions) ->
    #Split the actions into two separate groups (actions below mean and actions above mean)
    #This is a useful heuristic to  
    action_list = Object.keys(actions)
    [actions_below_mean, actions_above_mean] = @half_array_by_mean(action_list, actions)

    bb.all([
      @esm.find_similar_people(person, actions_below_mean, action, @similar_people_limit, @person_history_limit), 
      @esm.find_similar_people(person, actions_above_mean, action, @similar_people_limit, @person_history_limit)])
    .spread( (ltpeople, gtpeople) ->
      _.unique(ltpeople.concat gtpeople)
    )

  recently_actioned_things_by_people: (action, people, related_things_limit) ->
    @esm.recently_actioned_things_by_people(action, people, @related_things_limit)

  crowd_weight_confidence: (weight, n_people) ->
    crowd_size = Math.pow(n_people, @crowd_weight)
    cwc = 1.0 - Math.pow(Math.E,( (- crowd_size) / 4 ))
    cwc * weight

  generate_recommendations_for_person: (person, action, actions, person_history_count = 1) ->
    @find_similar_people(person, action, actions)
    .then( (people) =>
      bb.all([
        @calculate_similarities_from_person(person, people, actions)
        @recently_actioned_things_by_people(action, people.concat(person), @related_things_limit)
      ])
    )
    .spread( ( similar_people, people_things ) =>
      people_weights = similar_people.people_weights
      things_weight = {}
      for p, things of people_things
        for thing_date in things
          thing = thing_date.thing
          last_actioned_at = thing_date.last_actioned_at

          things_weight[thing] = {thing: thing, weight: 0} if things_weight[thing] == undefined
          recommendation_info = things_weight[thing]
          recommendation_info.weight += people_weights[p]
          recommendation_info.people = [] if recommendation_info.people == undefined
          recommendation_info.people.push p
          if recommendation_info.last_actioned_at == undefined or recommendation_info.last_actioned_at < last_actioned_at
            recommendation_info.last_actioned_at = last_actioned_at
            
            
      for thing, ri of things_weight
        ri.weight = @crowd_weight_confidence(ri.weight, ri.people.length)

      # CALCULATE CONFIDENCES
      bb.all([@filter_recommendations(person, things_weight), similar_people] )
    )
    .spread( (recommendations, similar_people) =>

      recommendations_object = {}

      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      sorted_things = recommendations.sort((x, y) -> y.weight - x.weight)
      recommendations_object.recommendations = sorted_things[0...@recommendations_limit]
      

      people_confidence = @people_confidence(similar_people.n_people)
      history_confidence = @history_confidence(person_history_count)
      things_confidence = @things_confidence(sorted_things)

      recommendations_object.confidence = people_confidence * history_confidence * things_confidence


      recommendations_object.similar_people = {}
      for rec in recommendations_object.recommendations
        for p in rec.people
          recommendations_object.similar_people[p] = similar_people.people_weights[p]

      recommendations_object

    )

  recommendations_for_person: (person, action) ->
    #first a check or two
    bb.all([@esm.person_history_count(person), @esm.get_actions()])
    .spread( (count, action_weights) =>
      if count < @minimum_history_limit
        return {recommendations: [], confidence: 0}
      else
        total_action_weight = 0
        for aw in action_weights
          total_action_weight += aw.weight
        #filter and normalize actions with 0 weight from actions
        actions = {}
        (actions[aw.key] = (aw.weight / total_action_weight) for aw in action_weights when aw.weight > 0)

        return @generate_recommendations_for_person(person, action, actions, count)
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

  find_events: (person, action, thing, options) ->
    @esm.find_events(person, action, thing, options)

  delete_events: (person, action, thing) ->
    @esm.delete_events(person, action, thing)

  namespace_exists: ->
    @esm.exists()

  set_namespace: (namespace) ->
    @esm.set_namespace(namespace)

  get_action:(action) ->
    @esm.get_action_weight(action)
    .then( (weight) -> 
      return null if weight == null || weight == undefined
      {action: action, weight: weight}
    )

  bootstrap: (stream) ->
    #filename should be person, action, thing, created_at, expires_at
    #this will require manually adding the actions
    @esm.bootstrap(stream)
    
  #  DATABASE CLEANING #
  compact_database: ->
    @esm.pre_compact()
    .then( =>
      promises = []
      promises.push @esm.expire_events()
      promises.push @esm.compact_people(@compact_database_person_action_limit)
      promises.push @esm.compact_things(@compact_database_thing_action_limit)
      bb.all(promises)
    )
    .then( =>
      @esm.post_compact()
    )

  compact_database_to_size: (number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    @esm.remove_events_till_size(number_of_events)


RET = {}

RET.GER = GER

knex = require 'knex'
r = require 'rethinkdbdash'
RET.knex = knex
RET.r = r

RET.PsqlESM = require('./lib/psql_esm')
RET.MemESM = require('./lib/basic_in_memory_esm')
RET.RethinkDBESM = require('./lib/rethinkdb_esm')


#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


