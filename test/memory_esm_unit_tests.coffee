chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

MEMORY_ESM = require('../lib/memory_esm')

q = require 'q'


init_esm = ->
  new MEMORY_ESM()


describe 'add_action', ->
  it 'should add the action with a weight to a sorted set', ->
    esm = init_esm()
    sinon.stub(esm.store, 'sorted_set_score', -> q.fcall(-> null))
    sinon.stub(esm.store, 'sorted_set_add', (key, action) -> 
      action.should.equal 'view'
    )
    esm.add_action('view')
    .then( -> sinon.assert.calledOnce(esm.store.sorted_set_add))

  it 'should not override the score if the action is already added', ->
    esm = init_esm()
    sinon.stub(esm.store, 'sorted_set_score', -> q.fcall(-> 3))
    sinon.stub(esm.store, 'sorted_set_add')
    esm.add_action('view')
    .then(-> sinon.assert.notCalled(esm.store.sorted_set_add))


describe 'set_action_weight', ->
  it 'will override an actions score', ->
    esm = init_esm()
    sinon.stub(esm.store, 'sorted_set_add', (key, action, score) -> 
      action.should.equal 'view'
      score.should.equal 5
    )
    esm.set_action_weight('view', 5)
    sinon.assert.calledOnce(esm.store.sorted_set_add)

describe 'jaccard metric', ->
  it 'should take two keys to sets and return a number', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_union', (s1,s2) -> ['1','2','3','4'])
    sinon.stub(esm.store, 'set_intersection', (s1,s2) -> ['2','3'])
    esm.people_jaccard_metric('p1','p2', 'a1').should.eventually.equal(.5)


describe 'add_thing_to_person_action_set', ->
  it 'should add thing to person action set in store, incrememnting by the number of times it occured', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_add', (key, thing) -> 
      thing.should.equal 'thing'
    )
    esm.add_thing_to_person_action_set('thing', 'action', 'person')
    sinon.assert.calledOnce(esm.store.set_add)

describe 'add_person_to_thing_action_set', ->
  it 'should add a person action set in store, incrememnting by the number of times it occured', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_add', (key, thing) -> 
      thing.should.equal 'thing'
    )
    esm.add_thing_to_person_action_set('thing', 'action', 'person')
    sinon.assert.calledOnce(esm.store.set_add)


describe '#add_event', ->
  it 'should take a person action thing and return promise', ->
    esm = init_esm()
    esm.add_event('person','action','thing')

  it 'should add the action to the set of actions', ->
    esm = init_esm()
    sinon.stub(esm, 'add_action')
    esm.add_event('person','action','thing')
    sinon.assert.calledOnce(esm.add_action)

  it 'should add to the list of things the person has done', ->
    esm = init_esm()
    sinon.stub(esm, 'add_thing_to_person_action_set', (thing, action, person) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    esm.add_event('person','action','thing')
    sinon.assert.calledOnce(esm.add_thing_to_person_action_set)

  it 'should add person to a list of people who did action to thing', ->
    esm = init_esm()
    sinon.stub(esm, 'add_person_to_thing_action_set', (person, action, thing) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    esm.add_event('person','action','thing')
    sinon.assert.calledOnce(esm.add_person_to_thing_action_set)



describe "#get_action_set", ->
  it 'should return a promise for the action things set', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_members')
    esm.get_action_set('action','thing')
    sinon.assert.calledOnce(esm.store.set_members)


describe '#get_thing_action_set', ->
  it 'should return a promise for the action things set', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_members')
    esm.get_thing_action_set('thing','action')
    sinon.assert.calledOnce(esm.store.set_members)

describe '#get_person_action_set', ->
  it 'should return a promise for the persons action set', ->
    esm = init_esm()
    sinon.stub(esm.store, 'set_members')
    esm.get_person_action_set('person','action')
    sinon.assert.calledOnce(esm.store.set_members)


describe '#get_actions_of_person_thing_with_scores', ->
  it 'should return action scores of just keys in actions', ->
    esm = init_esm()
    sinon.stub(esm, 'get_action_set_with_scores', -> q.fcall(-> [{key: 'view', score: 1} , {key: 'buy', score: 2} ]))
    sinon.stub(esm.store, 'set_members', -> q.fcall(-> ['buy']))
    esm.get_actions_of_person_thing_with_scores('x','y')
    .then( (action_scores) ->
      action_scores.length.should.equal 1
      action_scores[0].key.should.equal 'buy'
      action_scores[0].score.should.equal 2
    )

describe '#get_action_set_with_scores', ->
  it 'should return the actions with the scores', ->
    esm = init_esm()
    sinon.stub(esm.store,'set_rev_members_with_score', -> return q.fcall(-> true))
    esm.get_action_set_with_scores().should.eventually.equal true


describe '#things_people_have_actioned', ->
  it 'should return a list of items that have been actioned by people', ->
    esm = init_esm()
    sinon.stub(esm.store,'set_union', (keys)->
      q.fcall( -> ['a', 'b'])
    )
    esm.things_people_have_actioned('viewed', ['p2','p3'])
    .then((items) ->
      ('a' in items).should.equal true
      ('b' in items).should.equal true
      items.length.should.equal 2
    )


describe '#has_person_actioned_thing', ->
  it 'should check store to see if a person contains a thing', ->
    esm = init_esm()
    sinon.stub(esm.store,'set_contains', (key,thing)-> thing.should.equal 'a')
    esm.has_person_actioned_thing('p1','view','a')
