bb = require 'bluebird'
_ = require 'underscore'

moment = require "moment"

#The only stateful things in GER are the ESM and the options 
class GER

  constructor: (@esm) ->

  ####################### Weighted people  #################################

  calculate_similarities_from_person : (namespace, person, people, actions, history_search_size, recent_event_days) ->
    @esm.calculate_similarities_from_person(namespace, person, people, Object.keys(actions), history_search_size, recent_event_days)
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
    
  
  filter_recommendations: (namespace, person, recommendations, filter_previous_actions) ->
    @esm.filter_things_by_previous_actions(namespace, person, Object.keys(recommendations), filter_previous_actions)
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


  find_similar_people: (namespace, person, actions, configuration) ->
    @esm.find_similar_people(namespace, person, Object.keys(actions), _.clone(configuration))
      

  recently_actioned_things_by_people: (namespace, actions, people, configuration) ->
    @esm.recently_actioned_things_by_people(namespace, Object.keys(actions), people, _.clone(configuration))


  calculate_recommendations_weights: (people_weights, people_things) ->
    things_weight = {}
    for p, things of people_things
      for thing_date in things
        thing = thing_date.thing
        last_actioned_at = thing_date.last_actioned_at
        last_expires_at = thing_date.last_expires_at

        things_weight[thing] = {thing: thing, weight: 0, last_actioned_at: null, last_expires_at: null} if things_weight[thing] == undefined
        recommendation_info = things_weight[thing]
        recommendation_info.weight += people_weights[p]
        recommendation_info.people = [] if recommendation_info.people == undefined
        recommendation_info.people.push p

        if recommendation_info.last_expires_at == undefined or recommendation_info.last_expires_at == null or recommendation_info.last_expires_at < last_expires_at
          recommendation_info.last_expires_at = last_expires_at if last_expires_at

        if recommendation_info.last_actioned_at == undefined or recommendation_info.last_actioned_at == null or recommendation_info.last_actioned_at < last_actioned_at
          recommendation_info.last_actioned_at = last_actioned_at

    things_weight

  generate_recommendations_for_person: (namespace, person, actions, person_history_count, configuration) ->

    @find_similar_people(namespace, person, actions, configuration)
    .then( (people) =>
      bb.all([
        @calculate_similarities_from_person(namespace, person, people, actions, configuration.history_search_size, configuration.recent_event_days)
        @recently_actioned_things_by_people(namespace, actions, people.concat(person), configuration)
      ])
    )
    .spread( ( similar_people, people_things ) =>
      people_weights = similar_people.people_weights
      things_weight = @calculate_recommendations_weights(people_weights, people_things)
 
      # CALCULATE CONFIDENCES
      bb.all([@filter_recommendations(namespace, person, things_weight, configuration.filter_previous_actions), similar_people] )
    )
    .spread( (recommendations, similar_people) =>

      recommendations_object = {}

      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      sorted_things = recommendations.sort((x, y) -> y.weight - x.weight)
      recommendations_object.recommendations = sorted_things[0...configuration.recommendations_limit]
      

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

  generate_recommendations_for_thing: (namespace, thing,  actions, thing_history_count, configuration) ->
    #find people that have actioned things
    promises = []
    for a,w of actions
      promises.push(bb.all([a, @esm.find_events(namespace, null, Object.keys(actions), thing, size: 100)]))

    bb.all(promises)
    .then( (action_things) =>
      similar_people = {people_weights: {}, n_people: 0}
      people = []
      for action_thing in action_things
        a = action_thing[0]
        for e in action_thing[1]

          p = e.person
          if not similar_people.people_weights[p]
            similar_people.people_weights[p] = 0 
            similar_people.n_people += 1
            people.push p

          similar_people.people_weights[p] += actions[a]


      bb.all([similar_people, @recently_actioned_things_by_people(namespace, actions, people, configuration)])
    )
    .spread( ( similar_people, people_things ) =>
      people_weights = similar_people.people_weights
      recommendations = @calculate_recommendations_weights(people_weights, people_things)
      delete recommendations[thing] #removing the original object
      recommendations = _.values(recommendations)

      sorted_things = recommendations

      recommendations_object = {}

      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      sorted_things = sorted_things.sort((x, y) -> y.weight - x.weight)
      recommendations_object.recommendations = sorted_things[0...configuration.recommendations_limit]
      

      people_confidence = @people_confidence(similar_people.n_people)
      history_confidence = @history_confidence(thing_history_count)
      things_confidence = @things_confidence(sorted_things)

      recommendations_object.confidence = people_confidence * history_confidence * things_confidence


      recommendations_object.similar_people = {}
      for rec in recommendations_object.recommendations
        for p in rec.people
          recommendations_object.similar_people[p] = similar_people.people_weights[p]

      recommendations_object
      
    )
    # weight people by the action weight
    # find things that those 
    # @recently_actioned_things_by_people(namespace, action, people.concat(person), configuration.related_things_limit)

  default_configuration: (configuration) ->
    _.defaults(configuration,
      minimum_history_required: 1,
      history_search_size: 500
      similar_people_limit: 25,
      related_things_limit: 10
      recommendations_limit: 20,
      recent_event_days: 14,
      filter_previous_actions: [],
      time_until_expiry: 0
      actions: {}
    )

  normalize_actions: (in_actions) ->
    total_action_weight = 0
    for action, weight of in_actions
      continue if weight <= 0
      total_action_weight += weight

    #filter and normalize actions with 0 weight from actions
    actions = {}
    for action, weight of in_actions
      continue if weight <= 0
      actions[action] = weight/total_action_weight
    actions

  recommendations_for_thing: (namespace, thing, configuration = {}) ->
    configuration = @default_configuration(configuration)

    #first a check or two
    #TODO minimum thing history count
    actions = @normalize_actions(configuration.actions)    
    return @generate_recommendations_for_thing(namespace, thing, actions, 0, configuration)


  recommendations_for_person: (namespace, person, configuration = {}) ->
    configuration = @default_configuration(configuration)

    #first a check or two
    @esm.person_history_count(namespace, person)
    .then( (count) =>
      if count < configuration.minimum_history_required
        return {recommendations: [], confidence: 0}
      else
        actions = @normalize_actions(configuration.actions)
         
        return @generate_recommendations_for_person(namespace, person, actions, count, configuration)
    )

  ##Wrappers of the ESM

  count_events: (namespace) ->
    @esm.count_events(namespace)

  estimate_event_count: (namespace) ->
    @esm.estimate_event_count(namespace)

  events: (events) ->
    @esm.add_events(events)
    .then( -> events)
    
  event: (namespace, person, action, thing, dates = {}) ->
    @esm.add_event(namespace, person,action, thing, dates)
    .then( -> {person: person, action: action, thing: thing})

  find_events: (namespace, person, action, thing, options) ->
    @esm.find_events(namespace, person, action, thing, options)

  delete_events: (namespace, person, action, thing) ->
    @esm.delete_events(namespace, person, action, thing)

  namespace_exists: (namespace) ->
    @esm.exists(namespace)

  initialize_namespace: (namespace) ->
    @esm.initialize(namespace)

  destroy_namespace: (namespace) ->
    @esm.destroy(namespace)

  bootstrap: (namespace, stream) ->
    #filename should be person, action, thing, created_at, expires_at
    #this will require manually adding the actions
    @esm.bootstrap(namespace, stream)
    
  #  DATABASE CLEANING #
  compact_database: ( namespace, options = {}) ->
    
    options = _.defaults(options,
      compact_database_person_action_limit: 1500
      compact_database_thing_action_limit: 1500
      actions: []
    )

    @esm.pre_compact(namespace)
    .then( =>
      promises = []
      promises.push @esm.compact_people(namespace, options.compact_database_person_action_limit, options.actions)
      promises.push @esm.compact_things(namespace, options.compact_database_thing_action_limit, options.actions)
      bb.all(promises)
    )
    .then( =>
      @esm.post_compact(namespace)
    )

  compact_database_to_size: (namespace, number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    @esm.remove_events_till_size(namespace, number_of_events)


RET = {}

RET.GER = GER

knex = require 'knex'
r = require 'rethinkdbdash'
RET.knex = knex
RET.r = r

RET.PsqlESM = require('./lib/psql_esm')
RET.MemESM = require('./lib/basic_in_memory_esm')
RET.RethinkDBESM = require('./lib/rethinkdb_esm')

Errors = require './lib/errors'

GER.NamespaceDoestNotExist = Errors.NamespaceDoestNotExist

module.exports = RET;


