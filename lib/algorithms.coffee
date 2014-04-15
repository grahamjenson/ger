q = require 'q'

GER_Algorithms =

  event: (person, verb, thing) ->
    return q.fcall(->) 


#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Algorithms)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Algorithms;
