chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER
q = require 'q'

describe '#get_action_set_with_scores', ->
  it 'should return the actions with the scores', ->
    ger = new GER
    sinon.stub(ger.store,'set_members_with_score', -> return q.fcall(-> true))
    ger.get_action_set_with_scores().should.eventually.equal true

describe '#reccommendations_for_action', ->
  it 'should return a list of reccommended items', ->
    ger = new GER
    sinon.stub(ger,'ordered_similar_people', () -> q.fcall(-> [{person: 'p1', score: 1}, {person: 'p2', score: 3}]))
    sinon.stub(ger,'things_a_person_hasnt_actioned_that_other_people_have', -> q.fcall(-> ['t1','t2']))
    sinon.stub(ger, 'weighted_probability_to_action_thing_by_people', (thing, action, people_scores) -> 
      if thing == 't1'
        return .2
      else if thing == 't2'
        return .5
      else
        throw 'bad thing'
    )
    ger.reccommendations_for_action('p1','view')
    .then( (thing_scores) -> 
      thing_scores[0].thing.should.equal 't2'
      thing_scores[0].score.should.equal .5
      thing_scores[1].thing.should.equal 't1'
      thing_scores[1].score.should.equal .2
    )

describe '#has_person_actioned_thing', ->
  it 'should check store to see if a person contains a thing', ->
    ger = new GER
    sinon.stub(ger.store,'contains', (key,thing)-> thing.should.equal 'a')
    ger.has_person_actioned_thing('p1','view','a')

describe '#weighted_probability_to_action_thing_by_people', ->
  it 'should return a weight an item will people', ->
    ger = new GER
    sinon.stub(ger,'has_person_actioned_thing', (person,action,thing) -> 
      action.should.equal 'view'
      thing.should.equal 'i1'
      if person == 'p1'
        return q.fcall( -> true)
      else if person == 'p2'
        return q.fcall( -> false)
      else
        throw 'bad person'
    )
    people_scores = [{person: 'p1', score: 1}, {person: 'p2', score: 3}]
    ger.weighted_probability_to_action_thing_by_people('i1', 'view', people_scores).should.eventually.equal .25


describe '#things_a_person_hasnt_actioned_that_other_people_have', ->
  it 'should return a list of items that have not been acted on but have by other people', ->
    ger = new GER
    sinon.stub(ger.store,'union_store', -> q.fcall( -> 3))
    sinon.stub(ger.store,'diff', -> q.fcall( -> ['i1','i2']))
    ger.things_a_person_hasnt_actioned_that_other_people_have('p1', 'viewed', ['p2','p3'])
    .then((items) ->
      ('i1' in items).should.equal true
      ('i2' in items).should.equal true
      items.length.should.equal 2
    )

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
      people[0].person.should.equal 'p3'
      people[1].person.should.equal 'p2'
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

