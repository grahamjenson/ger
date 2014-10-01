chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

g = require('../ger')
GER = g.GER

knex = g.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})

PsqlESM = g.PsqlESM

bb = require 'bluebird'

init_ger = ->
  return new GER(new PsqlESM(knex))


describe '#recommendations_for_person', ->
  it 'should return a list of reccommended items', ->
    ger = init_ger()
    sinon.stub(ger,'weighted_similar_people', () -> bb.try(-> {map: {'p1':1, 'p2':3}, people : ['p1','p2'] , total_weight: 4, ordered_list : [['p2',3],['p1',1]]}))
    sinon.stub(ger.esm,'things_people_have_actioned', -> bb.try(-> ['t1','t2']))
    sinon.stub(ger, 'weighted_probabilities_to_action_things_by_people', (things, action, people_weights) -> 
      return {'t1':0.2 , 't2': 0.5}
    )
    ger.recommendations_for_person('p1','view')
    .then( (thing_weights) -> 
      thing_weights[0].thing.should.equal 't2'
      thing_weights[0].weight.should.equal .5
      thing_weights[1].thing.should.equal 't1'
      thing_weights[1].weight.should.equal .2
    )


describe '#weighted_similar_people', ->
  it 'should return a list of similar people ordered by similarity', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'get_ordered_action_set_with_weights', -> bb.try -> [{key: 'a', weight: 1}])
    sinon.stub(ger, 'similar_people_for_action_with_weights', -> bb.try -> [{'p3': 1}, {'p3': 1}, {'p2': 1}] )
    ger.weighted_similar_people('p1')
    .then((people) ->
      people.ordered_list[0][0].should.equal 'p1'
      people.ordered_list[1][0].should.equal 'p3'
      people.ordered_list[1][1].should.equal 2
      people.ordered_list[2][0].should.equal 'p2'
    )




describe '#event', ->
  it 'should take a person action thing and return promise', ->
    ger = init_ger()
    ger.event('person','action','thing')

  it 'should add the action to the set of actions', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'add_event', -> bb.try(->))
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.esm.add_event)


