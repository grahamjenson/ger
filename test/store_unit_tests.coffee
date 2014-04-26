chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

Store = require('../lib/store')
GER_Models = require('../lib/models')
Set = GER_Models.Set

q = require 'q'

describe 'Store', ->
  it 'should be instanciatable', ->
    store = new Store()

  it 'should be init with init object', ->
    store = new Store({'x': '1', 'y': '2'})
    store.get('x').should.eventually.equal '1'

  it 'should set a value to a key, and return a promise', ->
    store = new Store()
    store.set('key','value').should.eventually.be.fulfilled

  it 'a value should be retrievable from the store with a key', ->
    store = new Store({'key': 'value'})
    store.get('key').should.eventually.equal 'value'

  describe '#union', ->
    it 'should return a promise for the union of two stored sets', ->
      set1 = new Set(['x'])
      set2 = new Set(['y'])
      store = new Store({'s1': set1, 's2': set2})
      store.union('s1','s2')
      .then((uset) -> 
        uset.contains(['x','y']).should.equal true
        uset.size().should.equal 2
      )
  
  describe '#intersection', ->
    it 'should return a promise for the intersection of two stored sets', ->
      set1 = new Set(['w','x'])
      set2 = new Set(['x','y'])
      store = new Store({'s1': set1, 's2': set2})

      store.intersection('s1','s2')
      .then((uset) -> 
        uset.contains(['x']).should.equal true
        uset.size().should.equal 1
      )

  it 'should take two keys to sets and return a number', ->
    store = new Store
    sinon.stub(store, 'union', (s1,s2) -> new Set(['1','2','3','4']))
    sinon.stub(store, 'intersection', (s1,s2) -> new Set(['2','3']))
    store.jaccard_metric('s1','s2').should.eventually.equal .5