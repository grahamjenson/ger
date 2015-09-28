bb = require 'bluebird'
_ = require 'lodash'

moment = require "moment"

#The only stateful things in GER are the ESM and the options
class GER

  constructor: (@esm) ->

  ####################### Weighted people  #################################

  calculate_similarities_from_thing: (namespace, thing, things, actions, configuration) ->
    @esm.calculate_similarities_from_thing(namespace, thing, things, actions, _.clone(configuration))

  calculate_similarities_from_person: (namespace, person, people, actions, configuration) ->
    @esm.calculate_similarities_from_person(namespace, person, people, actions, _.clone(configuration))
    .then( (similarities) =>
      similarities[person] = 1 #manually add person to weights
      similarities
    )

  filter_recommendations: (namespace, person, recommendations, filter_previous_actions) ->
    recommended_things = _.uniq( (x.thing for x in recommendations) )
    @esm.filter_things_by_previous_actions(namespace, person, recommended_things, filter_previous_actions)
    .then( (filtered_recommendations) ->
      filtered_recs = []
      for rec in recommendations
        if rec.thing in filtered_recommendations
          filtered_recs.push rec

      filtered_recs
    )

  filter_similarities: (similarities) ->
    ns = {}
    for pt, weight of similarities
      if weight != 0
        ns[pt] = weight
    ns

  neighbourhood_confidence: (n_values ) ->
    #The more similar people found, the more we trust the recommendations
    #15 is a magic number chosen to make 10 around 50% and 50 around 95%
    pc = 1.0 - Math.pow(Math.E,( (- n_values) / 15 ))
    #The person confidence multiplied by the mean distance
    pc

  history_confidence: (n_history) ->
    # The more hisotry (input) the more we trust the recommendations
    # 35 is a magic number to make 100 about 100%
    hc = 1.0 - Math.pow(Math.E,( (- n_history) / 35 ))
    hc

  recommendations_confidence: (recommendations) ->
    return 0 if recommendations.length == 0
    # The greater the mean recommendation the more we trust the recommendations
    # 2 is a magic number to make 10 about 100%
    total_weight = 0
    for r in recommendations
      total_weight += r.weight

    mean_weight = total_weight/recommendations.length
    tc = 1.0 - Math.pow(Math.E,( (- mean_weight) / 2 ))

    tc

  person_neighbourhood: (namespace, person, actions, configuration) ->
    @esm.person_neighbourhood(namespace, person, Object.keys(actions), _.clone(configuration))

  thing_neighbourhood: (namespace, thing, actions, configuration) ->
    @esm.thing_neighbourhood(namespace, thing, Object.keys(actions), _.clone(configuration))

  recent_recommendations_by_people: (namespace, actions, people, configuration) ->
    @esm.recent_recommendations_by_people(namespace, Object.keys(actions), people, _.clone(configuration))

  calculate_people_recommendations: (similarities, recommendations, configuration) ->
    thing_group = {}


    for rec in recommendations
      if thing_group[rec.thing] == undefined
        thing_group[rec.thing] = {
          thing: rec.thing
          weight: 0
          last_actioned_at: rec.last_actioned_at
          last_expires_at: rec.last_expires_at
          people: []
        }

      thing_group[rec.thing].last_actioned_at = moment.max(moment(thing_group[rec.thing].last_actioned_at), moment(rec.last_actioned_at)).format()
      thing_group[rec.thing].last_expires_at = moment.max(moment(thing_group[rec.thing].last_expires_at), moment(rec.last_expires_at)).format()

      thing_group[rec.thing].weight += similarities[rec.person]

      thing_group[rec.thing].people.push rec.person

    recommendations = []
    for thing, rec of thing_group
      recommendations.push rec

    recommendations = recommendations.sort((x, y) -> y.weight - x.weight)
    recommendations


  calculate_thing_recommendations: (thing, similarities, neighbourhood, configuration) ->
    recommendations = []

    for rec in neighbourhood
      recommendations.push {
        thing: rec.thing
        weight: rec.people.length * similarities[rec.thing] # could be more subtle than n_people * similarity
        last_actioned_at: rec.last_actioned_at
        last_expires_at: rec.last_expires_at
        people: rec.people
      }

    recommendations = recommendations.sort((x, y) -> y.weight - x.weight)
    recommendations

  generate_recommendations_for_person: (namespace, person, actions, person_history_count, configuration) ->
    #"Recommendations for a Person"

    @person_neighbourhood(namespace, person, actions, configuration)
    .then( (people) =>
      bb.all([
        people,
        @calculate_similarities_from_person(namespace, person, people, actions, _.clone(configuration))
        @recent_recommendations_by_people(namespace, actions, people.concat(person), _.clone(configuration))
      ])
    )
    .spread( ( neighbourhood, similarities, recommendations ) =>
      bb.all([
        neighbourhood,
        similarities,
        @filter_recommendations(namespace, person, recommendations, configuration.filter_previous_actions)
      ])
    )
    .spread( (neighbourhood, similarities, recommendations) =>
      recommendations_object = {}
      recommendations_object.recommendations = @calculate_people_recommendations(similarities, recommendations, configuration)
      recommendations_object.neighbourhood = @filter_similarities(similarities)

      neighbourhood_confidence = @neighbourhood_confidence(neighbourhood.length)
      history_confidence = @history_confidence(person_history_count)
      recommendations_confidence = @recommendations_confidence(recommendations_object.recommendations)

      recommendations_object.confidence = neighbourhood_confidence * history_confidence * recommendations_confidence

      recommendations_object
    )

  generate_recommendations_for_thing: (namespace, thing,  actions, thing_history_count, configuration) ->
    #"People who Actioned this Thing also Actioned"

    @thing_neighbourhood(namespace, thing, actions, configuration)
    .then( (thing_neighbours) =>
      things = (nei.thing for nei in thing_neighbours)
      bb.all([
        thing_neighbours,
        @calculate_similarities_from_thing(namespace, thing , things, actions, _.clone(configuration))
      ])
    )
    .spread( (neighbourhood, similarities) =>
      recommendations_object = {}
      recommendations_object.recommendations = @calculate_thing_recommendations(thing, similarities, neighbourhood, configuration)
      recommendations_object.neighbourhood = @filter_similarities(similarities)

      neighbourhood_confidence = @neighbourhood_confidence(neighbourhood.length)
      history_confidence = @history_confidence(thing_history_count)
      recommendations_confidence = @recommendations_confidence(recommendations_object.recommendations)

      recommendations_object.confidence = neighbourhood_confidence * history_confidence * recommendations_confidence

      #console.log JSON.stringify(recommendations_object,null,2)

      recommendations_object
    )
    # weight people by the action weight
    # find things that those
    # @recent_recommendations_by_people(namespace, action, people.concat(person), configuration.recommendations_per_neighbour)

  default_configuration: (configuration) ->
    _.defaults(configuration,
      minimum_history_required: 1,
      neighbourhood_search_size: 100
      similarity_search_size: 100
      event_decay_rate: 1
      neighbourhood_size: 25,
      recommendations_per_neighbour: 5
      filter_previous_actions: [],
      time_until_expiry: 0
      actions: {},
      current_datetime: new Date() #set the current datetime, useful for testing and ML,
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
    actions = configuration.actions

    @find_events(namespace, actions: Object.keys(actions), thing: thing, current_datetime: configuration.current_datetime, size: 100)
    .then( (events) =>
      return {recommendations: [], confidence: 0} if events.length < configuration.minimum_history_required

      return @generate_recommendations_for_thing(namespace, thing, actions, events.length, configuration)
    )


  recommendations_for_person: (namespace, person, configuration = {}) ->
    configuration = @default_configuration(configuration)
    actions = configuration.actions

    #first a check or two
    @find_events(namespace, actions: Object.keys(actions), person: person, current_datetime: configuration.current_datetime, size: 100)
    .then( (events) =>

      return {recommendations: [], confidence: 0} if events.length < configuration.minimum_history_required

      return @generate_recommendations_for_person(namespace, person, actions, events.length, configuration)
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

  find_events: (namespace, options = {}) ->
    @esm.find_events(namespace, options)

  delete_events: (namespace, person, action, thing) ->
    @esm.delete_events(namespace, person, action, thing)

  namespace_exists: (namespace) ->
    @esm.exists(namespace)

  list_namespaces: () ->
    @esm.list_namespaces()

  initialize_namespace: (namespace) ->
    @esm.initialize(namespace)

  destroy_namespace: (namespace) ->
    @esm.destroy(namespace)

  #  DATABASE CLEANING #
  compact_database: ( namespace, options = {}) ->

    options = _.defaults(options,
      compact_database_person_action_limit: 1500
      compact_database_thing_action_limit: 1500
      actions: []
    )

    @esm.pre_compact(namespace)
    .then( =>
      @esm.compact_people(namespace, options.compact_database_person_action_limit, options.actions)
    )
    .then( =>
      @esm.compact_things(namespace, options.compact_database_thing_action_limit, options.actions)
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
RET.knex = knex

RET.PsqlESM = require('./lib/psql_esm')
RET.MemESM = require('./lib/basic_in_memory_esm')

Errors = require './lib/errors'

GER.NamespaceDoestNotExist = Errors.NamespaceDoestNotExist

module.exports = RET;


