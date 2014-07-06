q = require 'q'

Utils =
  flatten: (arr) ->
    arr.reduce ((xs, el) ->
      if Array.isArray el
        xs.concat Utils.flatten el
      else
        xs.concat [el]), []

  unique : (arr)->
    output = {}
    output[arr[key]] = arr[key] for key in [0...arr.length]
    value for key, value of output

class GER
  Config:
    PRE_ACTION_SCORE: 10 # this is just the default

  constructor: (@esm) ->
    
    plural =
      'person' : 'people'
      'thing' : 'things'

    #defining mirror methods (methods that need to be reversable)
    for v in [{object: 'person', subject: 'thing'}, {object: 'thing', subject: 'person'}]
      do (v) =>
        ####################### GET SIMILAR OBJECTS TO OBJECT #################################
        @["similar_#{plural[v.object]}_for_action"] = (object, action) =>
          #return a list of similar objects, later will be breadth first search till some number is found
          @esm["get_#{v.object}_action_set"](object, action)
          .then( (subjects) => q.all((@esm["get_#{v.subject}_action_set"](subject, action) for subject in subjects)))
          .then( (objects) => Utils.flatten(objects)) #flatten list
          .then( (objects) => objects.filter (s_object) -> s_object isnt object) #remove original object
          .then( (objects) => Utils.unique(objects)) #return unique list

        @["similarity_between_#{plural[v.object]}_for_action"] =  (object1, object2, action_key, action_weight) =>
          if object1 == object2
            return q.fcall(-> 1 * action_weight)
          @esm["#{plural[v.object]}_jaccard_metric"](object1, object2, action_key)
          .then( (jm) -> jm * action_weight)

        @["similarity_between_#{plural[v.object]}"] = (object1, object2) =>
          #return a value of a persons similarity
          @esm.get_action_set_with_weights()
          .then((actions) => q.all( (@["similarity_between_#{plural[v.object]}_for_action"](object1, object2, action.key, action.weight) for action in actions) ) )
          .then((sims) => sims.reduce (x,y) -> x + y )

        @["similarity_to_#{plural[v.object]}"] = (object, objects) =>
          q.all( (q.all([o, @["similarity_between_#{plural[v.object]}"](object, o)]) for o in objects) )
        
        @["similar_#{plural[v.object]}"] = (object) =>
          #TODO adding weights to actions could reduce number of objects returned
          @esm.get_action_set()
          .then( (actions) => q.all( (@["similar_#{plural[v.object]}_for_action"](object, action) for action in actions) ) )
          .then( (objects) => Utils.flatten(objects)) #flatten list
          .then( (objects) => Utils.unique(objects)) #return unique list
        
        @["ordered_similar_#{plural[v.object]}"] = (object) ->
          #TODO expencive call, could be cached for a few days as ordered set
          @["similar_#{plural[v.object]}"](object)
          .then( (objects) => @["similarity_to_#{plural[v.object]}"](object, objects) )
          .then( (weight_objects) => 
            sorted_objects = weight_objects.sort((x, y) -> y[1] - x[1])
            for p in sorted_objects
              temp = {weight: p[1]}
              temp[v.object] = p[0]
              temp
          )



  probability_of_person_actioning_thing: (object, action, subject) =>
      #probability of actions s
      #if it has already actioned it then it is 100%
      @esm.has_person_actioned_thing(object, action, subject)
      .then((inc) => 
        if inc 
          return 1
        else
          #TODO should return action_weight/total_action_weights e.g. view = 1 and buy = 10, return should equal 1/11
          @esm.get_actions_of_person_thing_with_weights(object, subject)
          .then( (action_weights) -> (as.weight for as in action_weights))
          .then( (action_weights) -> action_weights.reduce( ((x,y) -> x+y ), 0 ))
      )

  weighted_probability_to_action_thing_by_people: (thing, action, people_weights) =>
    # objects_weights [{person: 'p1', weight: 1}, {person: 'p2', weight: 3}]
    #returns the weighted probability that a group of people (with weights) actions the thing
    #add all the weights together of the people who have actioned the thing 
    #divide by total weights of all the people
    total_weights = (p.weight for p in people_weights).reduce( (x,y) -> x + y )
    q.all( (q.all([ps, @esm.has_person_actioned_thing(ps.person, action, thing) ]) for ps in people_weights) )
    .then( (person_probs) -> ({person: pp[0].person, weight: pp[0].weight * pp[1]} for pp in person_probs))
    .then( (people_with_item) -> (p.weight for p in people_with_item).reduce( ((x,y) -> x + y ), 0)/total_weights)

  weighted_probabilities_to_action_things_by_people : (subjects, action, object_weights) =>
    list_of_promises = (q.all([subject, @weighted_probability_to_action_thing_by_people(subject, action, object_weights)]) for subject in subjects)
    q.all( list_of_promises )



  reccommendations_for_thing: (thing, action) ->
    @esm.get_thing_action_set(thing, action)
    .then( (people) =>
      list_of_promises = q.all( (@ordered_similar_people(p) for p in people) )
      q.all( [people, list_of_promises] )
    )
    .spread( (people, peoples_lists) =>
      people_weights = Utils.flatten(peoples_lists)

      temp = {}
      for ps in people_weights
        temp[ps.person] = ps.weight

      for p in people
        if temp[p]
          temp[p] += @Config.PRE_ACTION_SCORE
        else
          temp[p] = @Config.PRE_ACTION_SCORE

      temp
    )
    .then( (reccommendations) ->
      weight_subjects = ([subject, weight] for subject, weight of reccommendations)
      sorted_subjects = weight_subjects.sort((x, y) -> y[1] - x[1])
      for ts in sorted_subjects
        temp = {weight: ts[1], person: ts[0]}
    )

  reccommendations_for_person: (person, action) ->
    #reccommendations for object action from similar people
    #reccommendations for object action from object, only looking at what they have already done
    #then join the two objects and sort
    @ordered_similar_people(person)
    .then( (object_weights) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      object_weights.push {weight: @Config.PRE_ACTION_SCORE, person: person}
      objects = (ps.person for ps in object_weights)
      q.all([object_weights, @esm.things_people_have_actioned(action, objects)])
    )
    .spread( ( object_weights, subjects) =>
      # Weight the list of subjects by looking for the probability they are actioned by the similar objects
      @weighted_probabilities_to_action_things_by_people(subjects, action, object_weights)
    )
    .then( (weight_subjects) =>
      temp = {}
      for ts in weight_subjects
        temp[ts[0]] = ts[1]
      temp
    )
    .then( (reccommendations) ->
      weight_subjects = ([subject, weight] for subject, weight of reccommendations)
      sorted_subjects = weight_subjects.sort((x, y) -> y[1] - x[1])
      for ts in sorted_subjects
        temp = {weight: ts[1], thing: ts[0]}
    )

  ##Wrappers of the ESM
  event: (person, action, thing) ->
    @esm.add_event(person,action,thing)

  set_action_weight: (action, weight) ->
    @esm.set_action_weight(action, weight)

  get_action_weight:(action) ->
    @esm.get_action_weight(action)

  add_action: (action) ->
    @esm.add_action(action)

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


