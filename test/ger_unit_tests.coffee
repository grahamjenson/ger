chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER

describe 'event', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    ger.event('person','action','thing')

  it 'should add the action to the set of actions', ->
    ger = new GER
    sinon.stub(ger, 'add_action')
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_action)

  it 'should add to the list of things the person has done', ->
    ger = new GER
    sinon.stub(ger, 'add_thing_to_person_action_set', (person, action, thing) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_thing_to_person_action_set)

  it 'should add person to a list of people who did action to thing', ->
    ger = new GER
    sinon.stub(ger, 'add_person_to_action_thing_set', (person, action, thing) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_person_to_action_thing_set)

describe 'add_thing_to_person_action_set', ->
  it 'should add thing to person action set in store, incrememnting by the number of times it occured', ->
    ger = new GER
    sinon.stub(ger.store, 'add_to_set', (key, thing) -> 
      thing.should.equal 'thing'
    )
    ger.add_thing_to_person_action_set('person', 'action', 'thing')
    sinon.assert.calledOnce(ger.store.add_to_set)

describe 'add_person_to_action_thing_set', ->
  it 'should add a person action set in store, incrememnting by the number of times it occured', ->
    ger = new GER
    sinon.stub(ger.store, 'add_to_set', (key, thing) -> 
      thing.should.equal 'thing'
    )
    ger.add_thing_to_person_action_set('person', 'action', 'thing')
    sinon.assert.calledOnce(ger.store.add_to_set)

describe 'add_action', ->
  it 'should add the action with a weight to a sorted set', ->
    ger = new GER
    sinon.stub(ger.store, 'add_to_sorted_set', (key, action, score) -> 
      action.should.equal 'view'
      score.should.equal 5
    )
    ger.add_action('view', 5)
    sinon.assert.calledOnce(ger.store.add_to_sorted_set)

