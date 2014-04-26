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
    it 'should return a promise for the union of two stored sets', ->
      set1 = new Set(['x'])
      set2 = new Set(['y'])
      kv_store = new KVStore({'s1': set1, 's2': set2})
      kv_store.union('s1','s2')
      .then((uset) -> 
        uset.contains(['x','y']).should.equal true
        uset.size().should.equal 2
      )
  
  describe '#intersection', ->
    it 'should return a promise for the intersection of two stored sets', ->
      set1 = new Set(['w','x'])
      set2 = new Set(['x','y'])
      kv_store = new KVStore({'s1': set1, 's2': set2})

      kv_store.intersection('s1','s2')
      .then((uset) -> 
        uset.contains(['x']).should.equal true
        uset.size().should.equal 1
      )

describe 'Set', ->
  it 'should be instanciatable', ->
    set = new Set
  
  it 'should be initialisable with a list of items that will be added', ->
    set = new Set(['1','2'])
    set.size().should.equal 2

  it 'should add value', ->
    set = new Set()
    set.add('value')

  it 'should have size',  ->
    set = new Set()
    set.size().should.equal 0
    set.add('value')
    set.size().should.equal 1


  it 'size should not change for same key', ->
    set = new Set()
    set.size().should.equal 0
    set.add('value')
    set.size().should.equal 1
    set.add('value')
    set.size().should.equal 1

  describe '#contains', ->

    it 'should contain the value', ->
      set = new Set()
      set.add('value')
      set.contains('value').should.equal true

    it 'should return false for values not in the set', ->
      set = new Set()
      set.contains('value').should.equal false

    it 'should return true if passed an array of contained items', ->
      set = new Set(['1','2'])

      set.contains(['1','2']).should.equal true

    it 'should return false if one of the values passed to contains is not contained', ->
      set = new Set(['1'])
      set.contains(['1','2']).should.equal false

  it 'should union with other sets to return a new set', ->
    set1 = new Set(['1'])
    set2 = new Set(['2'])
    uset = set1.union(set2)
    uset.contains(['1','2']).should.equal true
    uset.size().should.equal 2

  it 'should intersect with other sets to return a new set', ->
    set1 = new Set(['1','2'])
    set2 = new Set(['2','3'])
    uset = set1.intersection(set2)
    uset.contains(['2']).should.equal true
    uset.size().should.equal 1

