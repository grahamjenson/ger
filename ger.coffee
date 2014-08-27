q = require 'q'

Utils =
  flatten: (arr) ->
    arr.reduce ((xs, el) ->
      if Array.isArray el
        xs.concat Utils.flatten el
      else
        xs.concat [el]), []

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


        @["similar_#{plural[v.object]}_for_action_with_weights"] = (object, action, weight) =>
          @["similar_#{plural[v.object]}_for_action"](object, action)
          .then( (objects) =>
            #add weights
            temp = []
            for o in objects
              t = {} 
              t[v.object] = o
              t.weight = weight
              temp.push t
            temp
          )


        @["ordered_similar_#{plural[v.object]}"] = (object) ->
          #TODO expencive call, could be cached for a few days as ordered set
          @esm.get_ordered_action_set_with_weights()
          .then( (action_weights) =>

            fn = (i) => 
              if i >= action_weights.length
                return q.fcall(-> null)
              else
                @["similar_#{plural[v.object]}_for_action_with_weights"](object, action_weights[i].key, action_weights[i].weight)

            @get_list_to_size(fn, 0, [], @esm.similar_objects_limit)  
          ) 
          .then( (object_weights) =>
            #join the weights together
            temp = {}
            for ow in object_weights
              if temp[ow[v.object]] == undefined
                temp[ow[v.object]] = 0
              temp[ow[v.object]] += ow.weight
            
            res = []
            for p,w of temp
              continue if p == object
              r = {}
              r[v.object] = p
              r.weight = w
              res.push r
            res = res.sort((x, y) -> y.weight - x.weight)
            res[...@esm.similar_objects_limit] #Cut it off with similar objects limit
          )

          
  get_list_to_size: (fn, i, list, size) =>
    #recursive promise that will resolve till either the end
    if list.length > size
      return q.fcall(-> list)
    fn(i)
    .then( (new_list) =>
      return q.fcall(-> list) if new_list == null 
      new_list = list.concat new_list
      i = i + 1
      @get_list_to_size(fn, i, new_list, size)
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
      ret = []
      for ts in sorted_things
        temp = {weight: ts[1], thing: ts[0]}
        ret.push(temp)
      ret
    ) 

  ##Wrappers of the ESM

  count_events: ->
    @esm.count_events()

  event: (person, action, thing, expires_at = null) ->
    @esm.add_event(person,action,thing, expires_at)
    .then( -> {person: person, action: action, thing: thing})

  set_action_weight: (action, weight) ->
    @esm.set_action_weight(action, weight)
    .then( -> {action: action, weight: weight}) 

  get_action_weight:(action) ->
    @esm.get_action_weight(action)

  add_action: (action) ->
    @esm.add_action(action)

  bootstrap: (stream) ->
    #filename should be person,action,thing,date
    #this will require manually adding the actions
    @esm.bootstrap(stream)
    

  #  DATABASE CLEANING #

  compact_database: ->
    # Do some smart (lossless) things to shrink the size of the database
    q.all( [ @esm.remove_expired_events(), @esm.remove_non_unique_events()] )


  compact_database_to_size: (number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    q.all([@esm.remove_superseded_events() , @esm.remove_excessive_user_events()])
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


