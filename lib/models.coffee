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

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Models)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Models;
