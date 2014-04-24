q = require 'q'


class GER
  event: (person, action, thing) ->
    return q.fcall(->) 

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


