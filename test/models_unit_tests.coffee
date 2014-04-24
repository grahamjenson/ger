chai = require 'chai' 
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

should = chai.should()
expect = chai.expect

sinon = require 'sinon'

q = require 'q'

ger_models = require('../lib/models')
KVStore = ger_models.KVStore
Set = ger_models.Set

describe 'KVStore', ->
  it 'should be instanciatable', ->
    kv_store = new KVStore()

  it 'should be init with init object', ->
    kv_store = new KVStore({'x': '1', 'y': '2'})
    kv_store.get('x').should.eventually.equal '1'

  it 'should set a value to a key, and return a promise', ->
    kv_store = new KVStore()
    kv_store.set('key','value').should.eventually.be.fulfilled

  it 'a value should be retrievable from the store with a key', ->
    kv_store = new KVStore({'key': 'value'})
    kv_store.get('key').should.eventually.equal 'value'

  describe '#union', ->
    it 'should return a promise for the union of two stored sets', (done) ->
      set1 = new Set
      set2 = new Set
      kv_store = new KVStore()

      p = []
      p.push kv_store.set('s1', set1)
      p.push kv_store.set('s2', set2)
      p.push set1.add('x')
      p.push set2.add('y')

      q.all(p)
      .then(-> kv_store.union('s1','s2'))
      .then((uset) -> 
        uset.contains(['x','y'])
        .then((v) -> v.should.equal true; uset.size())
        .then((s) -> s.should.equal 2)
        .fail(done)
        return
      )
      .then(done, done)
  
  describe '#intersection', ->
    it 'should return a promise for the intersection of two stored sets', (done) ->
      set1 = new Set
      set2 = new Set
      kv_store = new KVStore()

      p = []
      p.push kv_store.set('s1', set1)
      p.push kv_store.set('s2', set2)
      p.push set1.add('w')
      p.push set1.add('x')
      p.push set2.add('x')
      p.push set2.add('y')

      q.all(p)
      .then(-> kv_store.intersection('s1','s2'))
      .then((uset) -> 
        uset.contains(['x'])
        .then((v) -> v.should.equal true; uset.size())
        .then((s) -> s.should.equal 1)
        .fail(done)
        return
      )
      .then(done, done)


describe 'Set', ->
  it 'should be instanciatable', ->
    set = new Set
  
  it 'should be initialisable with a list of items that will be added', (done) ->
    set = new Set(['1','2'])
    set.size()
    .then((size) -> size.should.equal 2; return)
    .then(done, done)

  it 'should add value and return a promise', (done) ->
    set = new Set()
    set.add('value')
    .then(done , done)

  it 'should have size', (done) ->
    set = new Set()
    set.size( (size) -> size.should.equal 0)
    .then(-> set.add('value'))
    .then(-> set.size())
    .then((size) -> size.should.equal 1; return)
    .then(done , done)


  it 'size should not change for same key', (done) ->
    set = new Set()
    set.size( (size) -> size.should.equal 0)
    .then(-> set.add('value'))
    .then(-> set.size())
    .then((size) -> size.should.equal 1; return)
    .then(-> set.add('value'))
    .then(-> set.size())
    .then((size) -> size.should.equal 1; return)
    .then(done , done)  

  describe '#contains', ->

    it 'should contain the value', (done) ->
      set = new Set()
      set.add('value')
      .then(-> set.contains('value'))
      .then((value) -> value.should.equal true; return)
      .then(done , done)

    it 'should return false for values not in the set', (done) ->
      set = new Set()
      set.contains('value')
      .then((value) -> value.should.equal false; return)
      .then(done , done)

    it 'should return true if passed an array of contained items', (done) ->
      set = new Set(['1','2'])

      set.contains(['1','2'])
      .then((value) -> value.should.equal true; return)
      .then(done,done)

    it 'should return false if one of the values passed to contains is not contained', (done) ->
      set = new Set(['1'])
      set.contains(['1','2'])
      .then((value) -> value.should.equal false; return)
      .then(done,done)

  it 'should union with other sets to return a new set', (done) ->
    set1 = new Set()
    set2 = new Set()
    q.all([set1.add('1'), set2.add('2')])
    .then(-> set1.union(set2))
    .then((nset) -> 
      nset.contains(['1','2'])
      .then((value) -> value.should.equal true)
      .then(-> nset.size())
      .then((size) -> size.should.equal 2)
      .fail(done)
      return
    )
    .then(done,done)

  it 'should intersect with other sets to return a new set', (done) ->
    set1 = new Set()
    set2 = new Set()
    q.all([set1.add('1'), set1.add('2'), set2.add('2'), set2.add('3')])
    .then(-> set1.intersection(set2))
    .then((nset) -> 
      nset.contains(['2'])
      .then((value) -> value.should.equal true)
      .then(-> nset.size())
      .then((size) -> size.should.equal 1)
      .fail(done)
      return
    )
    .then(done,done)
