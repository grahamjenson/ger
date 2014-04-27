chai = require 'chai' 
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

should = chai.should()
expect = chai.expect

sinon = require 'sinon'

q = require 'q'

ger_models = require('../lib/models')
Set = ger_models.Set
SortedSet = ger_models.SortedSet

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

describe 'SortedSet', ->
    it 'should have add with score', ->
      set = new SortedSet
      set.add('1',1)

    it 'should return members in order of score', ->
      set = new SortedSet
      set.add('a',2)
      set.add('b',1)
      members = set.members()
      members[0].should.equal 'b'
      members[1].should.equal 'a'

    it 'should return revmembers in order of score', ->
      set = new SortedSet
      set.add('a',1)
      set.add('b',2)
      members = set.revmembers()
      members[0].should.equal 'b'
      members[1].should.equal 'a'

    it 'should have a score', ->
      set = new SortedSet
      set.add('b',2)
      set.score('b').should.equal 2
    describe '#increment', ->
      it 'should increment values', ->
        set = new SortedSet
        set.add('b',2)
        set.increment('b',2)
        set.score('b').should.equal 4

      it 'should add values if they dont exist', ->
        set = new SortedSet
        set.increment('b',2)
        set.score('b').should.equal 2

