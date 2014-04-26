q = require 'q'

GER_Models= {}

#Meant to be an in memory stub of redis
# client.sinter
# client.sunion
# client.scard
# client.smembers
# client.sunionstore
# client.sdiff
# client.del
# client.zadd
# client.zscore
# client.zrevrange
# client.zrange
# client.zremrangebyrank
# client.zcard

class KVStore
  constructor: (ivals = {}) ->
    @store = ivals

  set: (key, value) ->
    return q.fcall(=> @store[key] = value; return) 
  
  get: (key) ->
    return  q.fcall(=> @store[key])

  union: (key1, key2) ->
    q.all([@.get(key1), @.get(key2)])
    .spread((set1, set2) -> set1.union(set2))

  intersection: (key1, key2) ->
    q.all([@.get(key1), @.get(key2)])
    .spread((set1, set2) -> set1.intersection(set2))
    

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

  members: ->
    return Object.keys(@store)


class OrderedSet extends Set
  add: (value, score) ->
      @store[value] = score

  members: -> 
    (m[1] for m in ([v , k] for k , v of @store).sort( (x) -> x[0]))

GER_Models.KVStore = KVStore
GER_Models.Set = Set
GER_Models.OrderedSet = OrderedSet

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Models)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Models;
