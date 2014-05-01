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
  add: (value, score) ->
      @store[value] = score

  members_with_score: ->
    @store

  members: -> 
    (m[1] for m in ([v , k] for k , v of @store).sort())

  revmembers: ->
    @members().reverse()

  score: (value) ->
    if !(value of @store)
      return null
    return @store[value]

  increment: (value, score) ->
    if !!@store[value]
     @add(value, @score(value) + score)
    else
      @add(value, score)

GER_Models.Set = Set
GER_Models.SortedSet = SortedSet

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Models)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Models;
