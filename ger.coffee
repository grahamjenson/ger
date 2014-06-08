q = require 'q'

Store = require('./lib/store')

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

KeyManager =
  action_set_key : ->
    'action_set'

  person_thing_set_key: (person, thing) ->
    "pt_#{person}:#{thing}"

  person_action_set_key: (person, action)->
    "ps_#{person}:#{action}"

  thing_action_set_key: (thing, action) ->
    "ta_#{thing}:#{action}"

  generate_temp_key: ->
    length = 8
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < length
    id.substr 0, length

class GER
  constructor: () ->
    @store = new Store

    plural =
      'person' : 'people'
      'thing' : 'things'

    #defining mirror methods (methods that need to be reversable)
    for v in [{object: 'person', subject: 'thing'}, {object: 'thing', subject: 'person'}]
      do (v) =>
        @["get_#{v.object}_action_set"] = (object, action) =>
          @store.set_members(KeyManager["#{v.object}_action_set_key"](object, action))

        @["add_#{v.object}_to_#{v.subject}_action_set"] = (object, action, subject) =>
          @store.set_add(
            KeyManager["#{v.subject}_action_set_key"](subject,action),
            object
          )

        @["similar_#{plural[v.object]}_for_action"] = (object, action) =>
          #return a list of similar objects, later will be breadth first search till some number is found
          @["get_#{v.object}_action_set"](object, action)
          .then( (subjects) => q.all((@["get_#{v.subject}_action_set"](subject, action) for subject in subjects)))
          .then( (objects) => Utils.flatten(objects)) #flatten list
          .then( (objects) => objects.filter (s_object) -> s_object isnt object) #remove original object
          .then( (objects) => Utils.unique(objects)) #return unique list

        @["similarity_between_#{plural[v.object]}_for_action"] =  (object1, object2, action_key, action_score) =>
          if object1 == object2
            return q.fcall(-> 1 * action_score)
          @jaccard_metric(KeyManager["#{v.object}_action_set_key"](object1, action_key), KeyManager["#{v.object}_action_set_key"](object2, action_key))
          .then( (jm) -> jm * action_score)

        @["similarity_between_#{plural[v.object]}"] = (object1, object2) =>
          #return a value of a persons similarity
          @get_action_set_with_scores()
          .then((actions) => q.all( (@["similarity_between_#{plural[v.object]}_for_action"](object1, object2, action.key, action.score) for action in actions) ) )
          .then((sims) => sims.reduce (x,y) -> x + y )

        @["similarity_to_#{plural[v.object]}"] = (object, objects) =>
          q.all( (q.all([o, @["similarity_between_#{plural[v.object]}"](object, o)]) for o in objects) )
        
        @["similar_#{plural[v.object]}"] = (object) =>
          #TODO adding weights to actions could reduce number of objects returned
          @get_action_set()
          .then( (actions) => q.all( (@["similar_#{plural[v.object]}_for_action"](object, action) for action in actions) ) )
          .then( (objects) => Utils.flatten(objects)) #flatten list
          .then( (objects) => Utils.unique(objects)) #return unique list
        
        @["ordered_similar_#{plural[v.object]}"] = (object) ->
          #TODO expencive call, could be cached for a few days as ordered set
          @["similar_#{plural[v.object]}"](object)
          .then( (objects) => @["similarity_to_#{plural[v.object]}"](object, objects) )
          .then( (score_objects) => 
            sorted_objects = score_objects.sort((x, y) -> y[1] - x[1])
            for p in sorted_objects
              temp = {score: p[1]}
              temp[v.object] = p[0]
              temp
          )

        @["#{plural[v.subject]}_a_#{v.object}_hasnt_actioned_that_other_#{plural[v.object]}_have"] = (object, action, objects) =>
          tempset = KeyManager.generate_temp_key()
          @store.set_union_then_store(tempset, (KeyManager["#{v.object}_action_set_key"](o, action) for o in objects))
          .then( => @store.set_diff([tempset, KeyManager["#{v.object}_action_set_key"](object, action)]))
          .then( (values) => @store.del(tempset); values)

        @["has_#{v.object}_actioned_#{v.subject}"] = (object, action, subject) ->
          @store.set_contains(KeyManager["#{v.object}_action_set_key"](object, action), subject)

        @["probability_of_#{v.object}_actioning_#{v.subject}"] = (object, action, subject) =>
            #probability of actions s
            #if it has already actioned it then it is 100%
            @["has_#{v.object}_actioned_#{v.subject}"](object, action, subject)
            .then((inc) => 
              if inc 
                return 1
              else
                #TODO should return action_score/total_action_scores e.g. view = 1 and buy = 10, return should equal 1/11
                @get_actions_of_person_thing_with_scores(object, subject)
                .then( (action_scores) -> (as.score for as in action_scores))
                .then( (action_scores) -> action_scores.reduce( ((x,y) -> x+y ), 0 ))
            )

        @["weighted_probability_to_action_#{v.subject}_by_#{plural[v.object]}"] = (subject, action, objects_scores) =>
          # objects_scores [{person: 'p1', score: 1}, {person: 'p2', score: 3}]
          #returns the weighted probability that a group of people (with scores) actions the thing
          #add all the scores together of the people who have actioned the thing 
          #divide by total scores of all the people
          total_scores = (p.score for p in objects_scores).reduce( (x,y) -> x + y )
          q.all( (q.all([ps, @["probability_of_#{v.object}_actioning_#{v.subject}"](ps[v.object], action, subject) ]) for ps in objects_scores) )
          .then( (person_probs) -> ({person: pp[0].person, score: pp[0].score * pp[1]} for pp in person_probs))
          .then( (people_with_item) -> (p.score for p in people_with_item).reduce( ((x,y) -> x + y ), 0)/total_scores)

        @["weighted_probabilities_to_action_#{plural[v.subject]}_by_#{plural[v.object]}"] = (subjects, action, object_scores) =>
          q.all( (q.all([subject, @["weighted_probability_to_action_#{v.subject}_by_#{plural[v.object]}"](subject, action, object_scores)]) for subject in subjects) )


        @["reccommendations_for_#{v.object}"] = (object, action) ->
          #returns a list of reccommended things
          #get a list of similar objects with scores
          #get a list of subjects that those objects have actioned, but person has not
          #weight the list of items
          #return list of items with weights
          @["ordered_similar_#{plural[v.object]}"](object)
          .then((object_scores) =>
            #objects is a list of similar objects not including 'object'
            objects = (ps[v.object] for ps in object_scores)
            q.all([object_scores, @["#{plural[v.subject]}_a_#{v.object}_hasnt_actioned_that_other_#{plural[v.object]}_have"](object, action, objects)])
          )
          .spread( ( object_scores, subjects) =>
            # a list of things
            @["weighted_probabilities_to_action_#{plural[v.subject]}_by_#{plural[v.object]}"](subjects, action, object_scores)
          )
          .then( (score_subjects) =>
            sorted_subjects = score_subjects.sort((x, y) -> y[1] - x[1])
            for ts in sorted_subjects
              temp = {score: ts[1]}
              temp[v.subject] = ts[0]
              temp
          )

  store: ->
    @store

  event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(thing,action,person),
      @add_person_to_thing_action_set(person,action,thing),
      @add_action_to_person_thing_set(person,action,thing)
      ])


  add_action_to_person_thing_set: (person, action, thing) =>
    @store.set_add(KeyManager.person_thing_set_key(person, thing), action)

  get_actions_of_person_thing_with_scores: (person, thing) =>
    q.all([@store.set_members(KeyManager.person_thing_set_key(person, thing)), @get_action_set_with_scores()])
    .spread( (actions, action_scores) ->
      (as for as in action_scores when as.key in actions)
    )
    

  get_action_set: ->
    @store.set_members(KeyManager.action_set_key())

  get_action_set_with_scores: ->
    @store.set_rev_members_with_score(KeyManager.action_set_key())


  add_action: (action) ->
    @get_action_weight(action)
    .then((existing_score) =>
      @store.sorted_set_add( KeyManager.action_set_key(), action) if existing_score == null
    )
  
  set_action_weight: (action, score) ->
    @store.sorted_set_add(KeyManager.action_set_key(), action, score)

  get_action_weight: (action) ->
    @store.sorted_set_score(KeyManager.action_set_key(), action)

  jaccard_metric: (s1,s2) ->
    q.all([@store.set_intersection([s1,s2]), @store.set_union([s1,s2])])
    .spread((int_set, uni_set) -> 
      ret = int_set.length / uni_set.length
      if isNaN(ret)
        return 0
      return ret
    )

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


