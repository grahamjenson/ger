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

  person_action_set_key: (person, action)->
    "#{person}:#{action}"

  thing_action_set_key: (thing, action) ->
    "#{thing}:#{action}"

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


  store: ->
    @store

  event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(thing,action,person),
      @add_person_to_thing_action_set(person,action,thing)
      ])

  get_person_action_set: (person, action) ->
    @store.set_members(KeyManager.person_action_set_key(person, action))

  get_thing_action_set: (thing, action) ->
    @store.set_members(KeyManager.thing_action_set_key(thing, action))

  has_person_actioned_thing: (person, action, thing) ->
    @store.set_contains(KeyManager.person_action_set_key(person, action), thing)

  get_action_set: ->
    @store.set_members(KeyManager.action_set_key())

  get_action_set_with_scores: ->
    @store.set_rev_members_with_score(KeyManager.action_set_key())

  ordered_similar_people: (person) ->
    #TODO expencive call, could be cached for a few days as ordered set
    @similar_people(person)
    .then( (people) => @similarity_to_people(person,people) )
    .then( (score_people) => 
      sorted_people = score_people.sort((x, y) -> y[1] - x[1])
      ({person: p[0], score: p[1]} for p in sorted_people) 
    )
  
  similarity_to_people : (person, people) ->
    q.all( (q.all([p, @similarity(person, p)]) for p in people) )

  similarity: (person1, person2) ->
    #return a value of a persons similarity
    @get_action_set_with_scores()
    .then((actions) => q.all( (@similarity_for_action(person1, person2, action.key, action.score) for action in actions) ) )
    .then((sims) => sims.reduce (x,y) -> x + y )


  similarity_for_action: (person1, person2, action_key, action_score) ->
    @store.jaccard_metric(KeyManager.person_action_set_key(person1, action_key), KeyManager.person_action_set_key(person2, action_key))
    .then( (jm) -> jm * action_score)

  similar_people: (person) ->
    #TODO adding weights to actions could reduce number of people returned
    @get_action_set()
    .then((actions) => q.all( (@similar_people_for_action(person, action) for action in actions) ) )
    .then( (people) => Utils.flatten(people)) #flatten list
    .then( (people) => Utils.unique(people)) #return unique list

  things_a_person_hasnt_actioned_that_other_people_have: (person, action, people) ->
    tempset = KeyManager.generate_temp_key()
    @store.set_union_then_store(tempset, (KeyManager.person_action_set_key(p, action) for p in people))
    .then( => @store.set_diff([tempset, KeyManager.person_action_set_key(person, action)]))
    .then( (values) => @store.del(tempset); values)

  weighted_probability_to_action_thing_by_people: (thing, action, people_scores) ->
    # people_scores [{person: 'p1', score: 1}, {person: 'p2', score: 3}]
    #returns the weighted probability that a group of people (with scores) actions the thing
    #add all the scores together of the people who have actioned the thing 
    #divide by total scores of all the people
    total_scores = (p.score for p in people_scores).reduce( (x,y) -> x + y )
    q.all( (q.all([ps, @has_person_actioned_thing(ps.person, action, thing)]) for ps in people_scores) )
    .then( (person_item_contains) -> (pic[0] for pic in person_item_contains when pic[1]))
    .then( (people_with_item) -> (p.score for p in people_with_item).reduce( (x,y) -> x + y )/total_scores)

  weighted_probabilities_to_action_things_by_people: (things, action, people_scores) ->
      q.all( (q.all([thing, @weighted_probability_to_action_thing_by_people(thing, action, people_scores)]) for thing in things) )

  reccommendations_for_person: (person, action) ->
    #returns a list of reccommended things
    #get a list of similar people with scores
    #get a list of items that those people have actioned, but person has not
    #weight the list of items
    #return list of items with weights
    @ordered_similar_people(person)
    .then((people_scores) =>
      people = (ps.person for ps in people_scores) 
      q.all([people_scores, @things_a_person_hasnt_actioned_that_other_people_have(person, action, people)])
    )
    .spread( ( people_scores, things) => @weighted_probabilities_to_action_things_by_people(things, action, people_scores))
    .then( (score_things) =>
      sorted_things = score_things.sort((x, y) -> y[1] - x[1])
      ({thing: ts[0], score: ts[1]} for ts in  sorted_things) 
    )


  reccommendations_for_thing: (thing, action) ->
    #returns a list of reccommended people that may action a thing
    #get a list of similar things with scores
    #get a list of people that have actioned those things, but not exactly actioned the thing (e.g. already 'bought' the 'thing')
    #weight the list of people
    #return list of people with weights

  add_action: (action) ->
    @get_action_weight(action)
    .then((existing_score) =>
      @store.sorted_set_add( KeyManager.action_set_key(), action) if existing_score == null
    )
  
  set_action_weight: (action, score) ->
    @store.sorted_set_add(KeyManager.action_set_key(), action, score)

  get_action_weight: (action) ->
    @store.sorted_set_score(KeyManager.action_set_key(), action)

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


