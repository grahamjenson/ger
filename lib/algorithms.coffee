q = require 'q'

#implement alorithms to be acted on a store

GER_Algorithms =
  # the jaccard metric outputs an objective measurement of the similarity between two sets
  jaccard_metric: (s1,s2,store) ->
    q.all([store.intersection(s1,s2), store.union(s1,s2)])
    .spread((int_set, uni_set) -> [int_set.size(), uni_set.size()])
    .spread((int_size,uni_size) -> int_size/uni_size)

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Algorithms)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Algorithms;
