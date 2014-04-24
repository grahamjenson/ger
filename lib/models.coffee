q = require 'q'

GER_Models= {}

class KVStore
  constructor: () ->
    @store = {}

  set: (key, value) ->
    return q.fcall(=> @store[key] = value; return) 
  
  get: (key) ->
    return  q.fcall(=> @store[key])

  union: (key1, key2) ->
    q.all([@.get(key1), @.get(key2)])
    .then((k) -> k[0].union(k[1]))

class Set
  constructor: () ->
    @store = {}

  add: (value) ->
    return q.fcall(=> @store[value] = true; return) 

  size: () ->
    @_iter().then((keys) -> keys.length)

  contains: (value) ->
    if Array.isArray(value)
      q.all((@.contains(v) for v in value))
      .then((contains_list) -> return contains_list.reduce((x,y) -> x && y))
    else
      q.fcall(=> !!@store[value]) 

  union: (set) ->
    nset = new Set
    q.all([ @_iter() , set._iter()])
    .then((l) -> 
      p = (nset.add(v) for v in l[0].concat(l[1]))
      q.all(p)
    )
    .then(-> nset)
  
  intersection: (set) ->
    nset = new Set
    q.all([ @_iter() , set._iter()])
    .then((l) => 
      p = (nset.add(v) for v in l[0].concat(l[1]) when (l[0].indexOf(v) != -1) && (l[1].indexOf(v) != -1)) 
      q.all(p)
    )
    .then(-> nset)

  _iter: ->
    return q.fcall( => Object.keys(@store))


GER_Models.KVStore = KVStore
GER_Models.Set = Set

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Models)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Models;
