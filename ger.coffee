bb = require 'bluebird'
_ = require 'underscore'

class GER

  constructor: (@esm) ->
    @INITIAL_PERSON_WEIGHT = 10

  ####################### Random similar people  #################################
  recent_people_for_action: (action, limit) ->
    @esm.get_recent_people_for_action(action, limit)

  ####################### Related people  #################################
  related_people_for_action: (object, action) ->
    @esm.get_things_that_actioned_person(object, action)
    .then( (subjects) => @esm.get_people_that_actioned_things(subjects, action))

  related_people: (object, actions) ->
    promises = []
    for ac, weight of actions
      promises.push @related_people_for_action(object, ac, weight)
    bb.all(promises)
    .then((objects) -> _.flatten(objects))

  ####################### Weighted people  #################################

  weighted_similar_people: (object, action) ->
    @esm.get_ordered_action_set_with_weights()
    .then( (action_weights) =>
      actions = {}
      (actions[aw.key] = aw.weight for aw in action_weights)
      bb.all([actions, @related_people(object, actions)])
    )
    .spread( (actions, objects) =>
      if objects.length == 0 # TODO under a limit
        bb.all([actions, @recent_people_for_action(action, 50)])
      else
        bb.all([actions, objects])
    )
    .spread( (actions, objects) =>
      bb.all([actions, _.unique(objects)])
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
      for person, weights of object_weights
        for ac, weight of weights
          temp[person] = 0 if person not of temp
          temp[person] += weight/total_weight * actions[ac]
      temp
    )

  recommendations_for_person: (person, action) ->
    #recommendations for object action from similar people
    #recommendations for object action from object, only looking at what they have already done
    #then join the two objects and sort
    @weighted_similar_people(person, action)
    .then( (people_weights) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      bb.all([people_weights, @esm.things_people_have_actioned(action, Object.keys(people_weights))])
    )
    .spread( ( people_weights, people_things) =>
      # Weight the list of subjects by looking for the probability they are actioned by the similar objects
      things_weight = {}
      for person, things of people_things
        for thing in things
          things_weight[thing] = 0 if things_weight[thing] == undefined
          things_weight[thing] += people_weights[person]
      things_weight
    )
    .then( (recommendations) ->
      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      weight_things = ([thing, weight] for thing, weight of recommendations)
      sorted_things = weight_things.sort((x, y) -> y[1] - x[1])
      ret = []
      for ts in sorted_things
        temp = {weight: ts[1], thing: ts[0]}
        ret.push(temp)
      ret
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
    # Do some smart (lossless) things to shrink the size of the database
    bb.all( [ @esm.remove_expired_events(), @esm.remove_non_unique_events()] )


  compact_database_to_size: (number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    bb.all([@esm.remove_superseded_events() , @esm.remove_excessive_user_events()])
    .then( => @count_events())
    .then( (count) => 
      if count <= number_of_events
        return count
      else
        @esm.remove_events_till_size(number_of_events)
    )


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


