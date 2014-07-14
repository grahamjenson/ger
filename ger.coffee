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

  constructor: (@esm) ->
    @INITIAL_PERSON_WEIGHT = 10

    plural =
      'person' : 'people'
      'thing' : 'things'

    #defining mirror methods (methods that need to be reversable)
    for v in [{object: 'person', subject: 'thing'}, {object: 'thing', subject: 'person'}]
      do (v) =>
        ####################### GET SIMILAR OBJECTS TO OBJECT #################################
        @["similar_#{plural[v.object]}_for_action"] = (object, action) =>
          #return a list of similar objects, later will be breadth first search till some number is found
          @esm["get_#{plural[v.subject]}_that_actioned_#{v.object}"](object, action)
          .then( (subjects) => @esm["get_#{plural[v.object]}_that_actioned_#{plural[v.subject]}"](subjects, action))
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
            #TODO CHANGE LIMITATION TO CONFIGURATION
            for p in sorted_objects[..20]
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


  weighted_probabilities_to_action_things_by_people : (things, action, people_weights) =>
    #select events where person is in object_weights and subject is in subjects
    # [person, action, subject]
    # 
    # return [[subject, weight]]
    total_weights = 0
    people = []
    people_keys = {}
    for p in people_weights
      total_weights += p.weight
      people.push p.person
      people_keys[p.person] = p.weight

    total_weight = (p.weight for p in people_weights).reduce( (x,y) -> x + y )

    @esm.events_for_people_action_things(people, action, things)
    .then( (events) ->
      things_weight = {}
      for e in events
        weight = people_keys[e.person]
        if things_weight[e.thing] == undefined
          things_weight[e.thing] = 0
        things_weight[e.thing] += weight

      normal_weights = {}
      for thing, weight of things_weight
        normal_weights[thing] = (weight/total_weight)

      normal_weights
    )




  recommendations_for_thing: (thing, action) ->
    @esm.get_people_that_actioned_thing(thing, action)
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
          temp[p] += @INITIAL_PERSON_WEIGHT
        else
          temp[p] = @INITIAL_PERSON_WEIGHT

      temp
    )
    .then( (recommendations) ->
      weighted_people = ([person, weight] for person, weight of recommendations)
      sorted_people = weighted_people.sort((x, y) -> y[1] - x[1])
      for ts in sorted_people
        temp = {weight: ts[1], person: ts[0]}
    )

  recommendations_for_person: (person, action) ->
    #recommendations for object action from similar people
    #recommendations for object action from object, only looking at what they have already done
    #then join the two objects and sort
    @ordered_similar_people(person)
    .then( (people_weights) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      people_weights.push {weight: @INITIAL_PERSON_WEIGHT, person: person}
      people = (ps.person for ps in people_weights)
      q.all([people_weights, @esm.things_people_have_actioned(action, people)])
    )
    .spread( ( people_weights, things) =>
      # Weight the list of subjects by looking for the probability they are actioned by the similar objects
      @weighted_probabilities_to_action_things_by_people(things, action, people_weights)
    )
    .then( (recommendations) ->
      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      weight_things = ([thing, weight] for thing, weight of recommendations)
      sorted_things = weight_things.sort((x, y) -> y[1] - x[1])
      for ts in sorted_things
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


