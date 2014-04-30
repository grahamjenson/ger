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

  action_thing_set_key: (action,thing) ->
    "#{action}:#{thing}"

  generate_temp_key: ->
    length = 8
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < length
    id.substr 0, length

class GER
  constructor: () ->
    @store = new Store

  store: ->
    @store

  event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(person,action,thing),
      @add_person_to_action_thing_set(person,action,thing)
      ])

  add_thing_to_person_action_set: (person , action, thing) ->
    @store.add_to_set(
      KeyManager.person_action_set_key(person, action),
      thing
    )

  add_person_to_action_thing_set: (person, action, thing) ->
    @store.add_to_set(
      KeyManager.action_thing_set_key(action, thing),
      person
    )

  get_person_action_set: (person, action) ->
    @store.set_members(KeyManager.person_action_set_key(person, action))

  has_person_actioned_thing: (person, action, thing) ->
    @store.contains(KeyManager.person_action_set_key(person, action), thing)

  get_action_thing_set: (action,thing) ->
    @store.set_members(KeyManager.action_thing_set_key(action, thing))

  get_action_set: ->
    @store.set_members(KeyManager.action_set_key())

  ordered_similar_people: (person) ->
    #TODO expencive call, could be cached for a few days as ordered set
    @similar_people(person)
    .then( (people) => q.all( (q.all([p, @similarity(person, p)]) for p in people)) )
    .then( (score_people) => ({person: p[0], score: p[1]} for p in score_people.sort((x) -> x[1] )) )
            
  similarity: (person1, person2) ->
    #return a value of a persons similarity
    @get_action_set()
    .then((actions) => q.all( (@similarity_for_action(person1, person2, action) for action in actions) ) )
    .then((sims) => sims.reduce (x,y) -> x + y )

  similarity_for_action: (person1, person2, action) ->
    @store.jaccard_metric(KeyManager.person_action_set_key(person1, action), KeyManager.person_action_set_key(person2, action))

  similar_people: (person) ->
    #TODO adding weights to actions could reduce number of people returned
    @get_action_set()
    .then((actions) => q.all( (@similar_people_for_action(person, action) for action in actions) ) )
    .then( (people) => Utils.flatten(people)) #flatten list
    .then( (people) => Utils.unique(people)) #return unique list

  similar_people_for_action: (person, action) ->
    #return a list of similar people, later will be breadth first search till some number is found
    @get_person_action_set(person, action)
    .then( (things) => q.all((@get_action_thing_set(action, thing) for thing in things)))
    .then( (people) => Utils.flatten(people)) #flatten list
    .then( (people) => people.filter (s_person) -> s_person isnt person) #remove original person
    .then( (people) => Utils.unique(people)) #return unique list

  things_a_person_hasnt_actioned_that_other_people_have: (person, action, people) ->
    tempset = KeyManager.generate_temp_key()
    @store.union_store(tempset, (KeyManager.person_action_set_key(p, action) for p in people))
    .then( => @store.diff([tempset, KeyManager.person_action_set_key(person, action)]))
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

  reccommendations_for_action: (person, action) ->
    #return list of things

  actions: ->
    #return a list of actions

  add_action: (action, score=1) ->
    @store.add_to_sorted_set(
      KeyManager.action_set_key(), 
      action, 
      score
    )
    #add action with weight

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


