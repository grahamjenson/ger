q = require 'q'



GER_Models = {}

class Set
  constructor: (ivals = []) ->
    @store = {}
    (@store[iv] = 1 for iv in ivals)

  add: (value) ->
    @store[value] = 1

  size: () ->
    @members().length

  contains: (value) ->
    if Array.isArray(value)
      (@.contains(v) for v in value).reduce((x,y) -> x && y)
    else
      !!@store[value]

  union: (set) ->
    new Set( (v for v in @members().concat(set.members())) )
  
  intersection: (set) ->
    s1 = @members()
    s2 = set.members()
    new Set(  (v for v in s1.concat(s2) when (s1.indexOf(v) != -1) && (s2.indexOf(v) != -1))  )
  
  diff: (set) ->
    s1 = @members()
    s2 = set.members()
    new Set( (v for v in s1.concat(s2) when (s1.indexOf(v) != -1) && (s2.indexOf(v) == -1))  )

  members: ->
    return Object.keys(@store)


class SortedSet extends Set
  add: (value, weight) ->
    @store[value] = weight

  sorted_member_weight_list: ->
    ({key: k, weight: v} for k , v of @store).sort((x, y) -> x.weight- y.weight)

  members_with_weight: ->
    @sorted_member_weight_list()

  rev_members_with_weights: ->
    @members_with_weight().reverse()

  members: -> 
    (m.key for m in @sorted_member_weight_list())

  revmembers: ->
    @members().reverse()

  weight: (value) ->
    if !(value of @store)
      return null
    return @store[value]

  increment: (value, weight) ->
    if !!@store[value]
     @add(value, @weight(value) + weight)
    else
      @add(value, weight)

GER_Models.Set = Set
GER_Models.SortedSet = SortedSet

class Store
  #BASIC METHODS
  constructor: (ivals = {}) ->
    @store = ivals

  set: (key, value) ->
    return q.fcall(=> @store[key] = value; return) 
  
  get: (key) ->
    return  q.fcall(=> @store[key])

  del: (key) ->
    return  q.fcall(=> value = @store[key]; delete(@store[key]); value)

  #SORTED SET CALLS
  sorted_set_incr: (key, value, weight) ->
    #redis.zincrby
    @_check_sorted_set(key)
    q.fcall(=> @store[key].increment(value, weight); return)

  sorted_set_add: (key, value, weight=1) ->
    #redis.zadd
    @_check_sorted_set(key)
    q.fcall(=> @store[key].add(value, weight); return)

  sorted_set_weight: (key, value) ->
    if !(key of @store)
      return q.fcall(-> null)
    q.fcall(=> @store[key].weight(value))


  _check_sorted_set: (key) ->
    if !(key of @store)
      @store[key] = new SortedSet()

  _check_set: (key) ->
    if !(key of @store)
      @store[key] = new Set()

  #SET METHODS
  set_add: (key,value) ->
    #redis.sadd
    @_check_set(key)
    q.fcall(=> @store[key].add(value); return)

  set_members: (key) ->
    if !(key of @store)
      return q.fcall(=> [])
    q.fcall(=> @store[key].members())

  set_rev_members_with_weight: (key) ->
    q.fcall(=> @store[key].rev_members_with_weights())

  set_members_with_weight: (key) ->
    q.fcall(=> @store[key].members_with_weight())

  set_contains: (key,value) ->
    #redis.SISMEMBER
    if !(key of @store)
      return q.fcall(-> false)
    q.fcall(=> @store[key].contains(value))  

  set_union_then_store: (store_key, keys) ->
    q.fcall( => un = @_union(keys); @store[store_key] = un; return un.size())

  set_diff: (keys) ->
    q.fcall( => @_diff(keys).members())

  set_union: (keys) ->
    q.fcall( => @_union(keys).members())

  set_intersection: (keys) ->
    q.fcall( => @_intersection(keys).members())

  _diff: (keys) ->
    (@store[k] for k in keys).reduce((s1,s2) -> 
      if s1? && s2?
        s1.diff(s2)
      else if s1?
        new Set(s1.members())
      else if s2?
        new Set(s2.members())
      else
        new Set()
    )

  _union: (keys) ->
    if keys.length == 0
      return new Set()
      
    (@store[k] for k in keys).reduce((s1,s2) -> 
      if s1? && s2?
        s1.union(s2)
      else if s1?
        new Set(s1.members())
      else if s2?
        new Set(s2.members())
      else
        new Set()
    )

  _intersection: (keys) ->
    (@store[k] for k in keys).reduce((s1,s2) -> 
      if s1? && s2?
        s1.intersection(s2)
      else
        new Set()
    )


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
    @event_count = 0

  count_events: () ->
    q.when(@event_count)
    
  add_event: (person, action, thing) ->
    @event_count += 1
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
    q.all([@store.set_members(KeyManager.person_thing_set_key(person, thing)), @get_ordered_action_set_with_weights()])
    .spread( (actions, action_weights) ->
      (as for as in action_weights when as.key in actions)
    )
    
  get_ordered_action_set_with_weights: ->
    @store.set_rev_members_with_weight(KeyManager.action_set_key())
    .then( (action_weights) -> action_weights.sort((x, y) -> y.weight - x.weight))


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

EventStoreMapper.Store = Store
EventStoreMapper.GER_Models = GER_Models

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return EventStoreMapper)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = EventStoreMapper;
