chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER
q = require 'q'

describe '#ordered_similar_people', ->
  it 'should return a list of similar people ordered by similarity', ->
    ger = new GER
    sinon.stub(ger, 'similar_people', -> q.fcall(-> ['p2', 'p3']))
    sinon.stub(ger, 'similarity', (person1, person2) ->
      person1.should.equal 'p1'
      if person2 == 'p2'
        return q.fcall(-> 0.3)
      else if person2 == 'p3'
        q.fcall(-> 0.4)
      else 
        throw 'bad person'
    )
    ger.ordered_similar_people('p1')
    .then((people) -> 
      people[0].should.equal 'p3'
      people[1].should.equal 'p2'
    )

describe '#similarity', ->
  it 'should find the similarity people by looking at their jaccard distance', ->
    ger = new GER
    sinon.stub(ger, 'get_action_set', -> q.fcall(-> ['view', 'buy']))
    sinon.stub(ger, 'similarity_for_action', (person1, person2, action) ->
      person1.should.equal 'p1'
      person2.should.equal 'p2'
      if action == 'view'
        return q.fcall(-> 0.3)
      else if action == 'buy'
        q.fcall(-> 0.4)
      else 
        throw 'bad action'
    )
    ger.similarity('p1','p2')
    .then((sim) -> 
      sim.should.equal .7
    )


describe "#similarity_for_action", ->
  it 'should find the similarity people by looking at their jaccard distance', ->
    ger = new GER
    sinon.stub(ger.store, 'jaccard_metric')
    ger.similarity_for_action('person1', 'person2', 'action')
    sinon.assert.calledOnce(ger.store.jaccard_metric) 

describe "#similar_people", ->
  it 'should compile a list of similar people for all actions', ->
    ger = new GER
    sinon.stub(ger, 'get_action_set', -> q.fcall(-> ['view']))
    sinon.stub(ger, 'similar_people_for_action', (person,action) ->
      person.should.equal 'person1'
      action.should.equal 'view' 
      q.fcall(-> ['person2'])
    )
    ger.similar_people('person1')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

describe '#similar_people_for_action', ->
  it 'should take a person and find similar people for an action', ->
    ger = new GER
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_action_thing_set', -> q.fcall(-> ['person2']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

  it 'should remove duplicate people', ->
    ger = new GER
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_action_thing_set', -> q.fcall(-> ['person2', 'person2']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

  it 'should remove the passed person', ->
    ger = new GER
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_action_thing_set', -> q.fcall(-> ['person2', 'person1']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

describe "#get_action_set", ->
  it 'should return a promise for the action things set', ->
    ger = new GER
    sinon.stub(ger.store, 'set_members')
    ger.get_action_set('action','thing')
    sinon.assert.calledOnce(ger.store.set_members)

describe '#get_action_thing_set', ->
  it 'should return a promise for the action things set', ->
    ger = new GER
    sinon.stub(ger.store, 'set_members')
    ger.get_person_action_set('action','thing')
    sinon.assert.calledOnce(ger.store.set_members)

describe '#get_person_action_set', ->
  it 'should return a promise for the persons action set', ->
    ger = new GER
    sinon.stub(ger.store, 'set_members')
    ger.get_person_action_set('person','action')
    sinon.assert.calledOnce(ger.store.set_members)



describe '#event', ->
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

