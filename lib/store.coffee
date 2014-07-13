q = require 'q'

GER_Models = require './models'
SortedSet = GER_Models.SortedSet
Set = GER_Models.Set

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


#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return Store)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = Store;