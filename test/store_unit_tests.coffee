chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

Store = require('../lib/store')
GER_Models = require('../lib/models')
Set = GER_Models.Set
SortedSet = GER_Models.SortedSet

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


  describe 'SORETED SET METHODS', ->
    describe '#sorted_set_item_score', ->
      it 'should return a promise for the score of the item', ->
        ss = new SortedSet()
        ss.add('i1',5)
        store = new Store({'s1': ss})
        store.sorted_set_item_score('s1', 'i1').should.eventually.equal 5

      it 'should return null if item does not exist', ->
        ss = new SortedSet()
        store = new Store({'s1': ss})
        store.sorted_set_item_score('s1', 'i1').should.eventually.equal null
      
      it 'should return null if set does not exist', ->
        store = new Store()
        store.sorted_set_item_score('s1', 'i1').should.eventually.equal null

    describe '#incr_to_sorted_set', ->
      it 'should increment the score of a item by a number', ->
        ss = new SortedSet()
        ss.add('i1',5)
        store = new Store({'s1': ss})
        store.incr_to_sorted_set('s1', 'i1', 1)
        .then( -> ss.score('i1').should.equal 6 )   
      
      it 'should create a set if there is none', ->
        store = new Store()
        store.incr_to_sorted_set('s1', 'i1', 1)
        .then( -> store.sorted_set_item_score('s1','i1').should.eventually.equal 1 )  

    describe '#add_to_sorted_set', ->
      it 'should add a value to a set', ->
        ss = new SortedSet()
        store = new Store({'s1': ss})
        store.add_to_sorted_set('s1', 'i1')
        .then( -> ss.contains('i1').should.equal true )

      it 'should create the sorted set if it does not exist', ->
        store = new Store()
        store.add_to_sorted_set('s1', 'i1')
        .then(-> store.get('s1'))
        .then( (ss) -> ss.contains('i1').should.equal true )

  describe 'SET METHODS', ->
    describe '#add_to_set', ->
      it 'should add to the set', ->
        ss = new Set()
        ss.add('i1')
        store = new Store({'s1': ss})
        store.add_to_set('s1', 'i1')
        .then( -> ss.contains('i1').should.equal true )   
      
      it 'should create a set if there is none', ->
        store = new Store()
        store.add_to_set('s1', 'i1')
        .then( -> store.contains('s1','i1').should.eventually.equal true )  

    describe '#set_members', ->
      it 'should return a list of members for key', ->
        store = new Store()
        store.add_to_set('s1', 'i1')
        .then( -> store.set_members('s1'))
        .then( (l) -> ('i1' in l).should.equal true)  

    describe '#contains', ->
      it 'should return true if element is a member', ->
        ss = new Set()
        ss.add('i1')
        store = new Store({'s1': ss})
        store.contains('s1', 'i1').should.eventually.equal true
      
      it 'should return false if element is a not member', ->
        ss = new Set()
        store = new Store({'s1': ss})
        store.contains('s1', 'i1').should.eventually.equal false

      it 'should return false if no key', ->
        store = new Store()
        store.contains('s1', 'i1').should.eventually.equal false

    describe '#union', ->
      it 'should return a promise for the union of two stored sets', ->
        set1 = new Set(['x'])
        set2 = new Set(['y'])
        store = new Store({'s1': set1, 's2': set2})
        store.union('s1','s2')
        .then((ulist) ->
          ('x' in ulist).should.equal true
          ('y' in ulist).should.equal true
          ulist.length.should.equal 2
        )
    
    describe '#intersection', ->
      it 'should return a promise for the intersection of two stored sets', ->
        set1 = new Set(['w','x'])
        set2 = new Set(['x','y'])
        store = new Store({'s1': set1, 's2': set2})

        store.intersection('s1','s2')
        .then((ulist) -> 
          ('x' in ulist).should.equal true
          ulist.length.should.equal 1
        )

  describe 'jaccard metric', ->
    it 'should take two keys to sets and return a number', ->
      store = new Store
      sinon.stub(store, 'union', (s1,s2) -> ['1','2','3','4'])
      sinon.stub(store, 'intersection', (s1,s2) -> ['2','3'])
      store.jaccard_metric('s1','s2').should.eventually.equal .5

