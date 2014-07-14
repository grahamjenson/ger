q = require 'q'
Store = require('../lib/store')

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


class EventStoreMapper

  constructor: () ->
    @store = new Store

  add_event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(thing,  action, person),
      @add_person_to_thing_action_set(person, action, thing),
      @add_action_to_person_thing_set(person, action, thing)
      ])

  events_for_people_action_things: (people, action, things) ->
    p = []
    events = []
    for person in people
      p.push q.all( [person, @get_things_that_actioned_person(person, action)])
    q.all(p)
    .then( (person_things) ->
      for pt in person_things
        person = pt[0]
        things = pt[1]
        for thing in things
          events.push {person: person, action: action, thing: thing} if thing in things
      events
    )
     


  things_people_have_actioned: (action, people) =>
    @store.set_union((KeyManager.person_action_set_key(p, action) for p in people))

  has_person_actioned_thing: (object, action, subject) ->
    @store.set_contains(KeyManager.person_action_set_key(object, action), subject)

  add_action_to_person_thing_set: (person, action, thing) =>
    @store.set_add(KeyManager.person_thing_set_key(person, thing), action)

  get_actions_of_person_thing_with_weights: (person, thing) =>
    q.all([@store.set_members(KeyManager.person_thing_set_key(person, thing)), @get_action_set_with_weights()])
    .spread( (actions, action_weights) ->
      (as for as in action_weights when as.key in actions)
    )
    
  get_action_set: ->
    @store.set_members(KeyManager.action_set_key())

  get_action_set_with_weights: ->
    @store.set_rev_members_with_weight(KeyManager.action_set_key())


  add_action: (action) ->
    @get_action_weight(action)
    .then((existing_weight) =>
      @store.sorted_set_add( KeyManager.action_set_key(), action) if existing_weight == null
    )
  
  set_action_weight: (action, weight) ->
    @store.sorted_set_add(KeyManager.action_set_key(), action, weight)

  get_action_weight: (action) ->
    @store.sorted_set_weight(KeyManager.action_set_key(), action)

  get_things_that_actioned_people: (people, action) =>
    return q.fcall(->[]) if people.length == 0
    p = []
    for person in people
      p.push @get_things_that_actioned_person(person, action)
    q.all(p)
    .then( (peoples) ->
      Utils.flatten(peoples)
    )

  get_people_that_actioned_things: (things, action) =>
    return q.fcall(->[]) if things.length == 0
    p = []
    for thing in things
      p.push @get_people_that_actioned_thing(thing, action)
    q.all(p)
    .then( (thingss) ->
      Utils.flatten(thingss)
    )
    
  get_things_that_actioned_person: (person, action) =>
    @store.set_members(KeyManager.person_action_set_key(person, action))

  get_people_that_actioned_thing: (thing, action) =>
    @store.set_members(KeyManager.thing_action_set_key(thing, action))

  add_person_to_thing_action_set: (person, action, thing) =>
    @store.set_add(KeyManager.thing_action_set_key(thing,action), person)

  add_thing_to_person_action_set: (thing, action, person) =>
    @store.set_add(KeyManager.person_action_set_key(person,action), thing)

  things_jaccard_metric: (thing1, thing2, action_key) ->
    s1 = KeyManager.thing_action_set_key(thing1, action_key)
    s2 = KeyManager.thing_action_set_key(thing2, action_key)
    q.all([@store.set_intersection([s1,s2]), @store.set_union([s1,s2])])
    .spread((int_set, uni_set) -> 
      ret = int_set.length / uni_set.length
      if isNaN(ret)
        return 0
      return ret
    ) 

  people_jaccard_metric: (person1, person2, action_key) ->
    s1 = KeyManager.person_action_set_key(person1, action_key)
    s2 = KeyManager.person_action_set_key(person2, action_key)
    q.all([@store.set_intersection([s1,s2]), @store.set_union([s1,s2])])
    .spread((int_set, uni_set) -> 
      ret = int_set.length / uni_set.length
      if isNaN(ret)
        return 0
      return ret
    )

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return EventStoreMapper)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = EventStoreMapper;
