chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_algorithms = require('../lib/algorithms')
ger_models = require('../lib/models')

KVStore = ger_models.KVStore
Set = ger_models.Set

q = require 'q'

describe 'jaccard_metric', ->
  it 'should take two keys to sets and return a number', ->
    store = new KVStore
    sinon.stub(store, 'union', (s1,s2) -> new Set(['1','2','3','4']))
    sinon.stub(store, 'intersection', (s1,s2) -> new Set(['2','3']))
    ger_algorithms.jaccard_metric('s1','s2', store).should.eventually.equal .5