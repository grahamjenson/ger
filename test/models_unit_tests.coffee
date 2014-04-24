chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_models = require('../lib/models')
KVStore = ger_models.KVStore

describe 'store', ->
  it 'should be instanciatable', ->
    kv_store = new KVStore()

  it 'should set a value to a key, and return a promise', (done) ->
    kv_store = new KVStore()
    kv_store.set('key','value')
    .then(done , done)
