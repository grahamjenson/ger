q = require 'q'

GER_Models= {}

class KVStore
  store: {}

  set: (key, value) ->
    return q.fcall(=> @store[key] = value; return) 
  
  get: (key) ->
    return  q.fcall(=> @store[key])

GER_Models.KVStore = KVStore

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GER_Models)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GER_Models;
