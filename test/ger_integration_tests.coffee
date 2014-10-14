chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'
bb = require 'bluebird'
bb.Promise.longStackTraces();

g = require('../ger')
GER = g.GER

PsqlESM = g.PsqlESM

knex = g.knex
  client: 'pg',
  connection: 
    host: '127.0.0.1', 
    user : 'root', 
    password : 'abcdEF123456', 
    database : 'ger_test'

compare_floats = (f1,f2) ->
  Math.abs(f1 - f2) < 0.00001

create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> PsqlESM.drop_tables(knex))
  .then( -> PsqlESM.init_tables(knex))
  .then( -> psql_esm)

esmfn = create_psql_esm

init_ger = ->
  esmfn().then( (esm) -> new GER(esm))

describe '#event', ->
  it 'should upsert same events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','c'),
        ger.event('p1','buy','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 1
      )

describe '#count_events', ->
  it 'should return 2 for 2 events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','buy','c'),
        ger.event('p1','view','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 2
      )

describe '#probability_of_person_actioning_thing', ->
  it 'should return 1 if the person has already actioned the object', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','buy','c'),
        ger.event('p1','view','c'),
      ])
      .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
      .then((probability) ->
        probability.should.equal 1
      )
    

  it 'should return 0 if the person has never interacted with the thing', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','buy','c'),
        ger.event('p1','view','c'),
      ])
      .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'd'))
      .then((probability) ->
        probability.should.equal 0
      )

  it 'should return the weight of the action', ->
    init_ger()
    .then (ger) ->
      ger.action('view', 5)
      .then(-> ger.event('p1','view','c'))
      .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
      .then((probability) ->
        probability.should.equal 5
      )

  it 'should return the sum of the weights of the action', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 5),
        ger.action('like', 10),
      ])
      .then( -> 
        bb.all([
          ger.event('p1','view','c'),
          ger.event('p1','like','c')
        ])
      )
      .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
      .then((probability) ->
        probability.should.equal 15
      )

describe 'recommendations_for_thing', ->
  it 'should take a thing and action and return people that it reccommends', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','view','c'),

        ger.event('p2','view','c'),
        ger.event('p2','buy','c'),

      ])
      .then(-> ger.recommendations_for_thing('c', 'buy'))
      .then((people_weights) ->
        people_weights[1].person.should.equal 'p1'
        people_weights.length.should.equal 2
      )

describe 'recommendations_for_person', ->
  
  it 'should reccommend basic things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
      ])
      .then(-> ger.recommendations_for_person('p2', 'buy'))
      .then((item_weights) ->
        item_weights[0].thing.should.equal 'a'
        item_weights.length.should.equal 1
      )

  it 'should take a person and action to reccommend things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','buy','c'),
        ger.event('p2','buy','d'),

        ger.event('p3','view','a'),
        ger.event('p3','buy','c')
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((item_weights) ->
        #p1 is similar to (p1 by 1), p2 by .5, and (p3 by .5)
        #p1 buys a (a is 1), p2 and p3 buys c (.5 + .5=1) and p2 buys d (.5)
        items = (i.thing for i in item_weights)
        (items[0] == 'a' or items[0] == 'c').should.equal true
        items[2].should.equal 'd'
      )

  it 'should take a person and reccommend some things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),

        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','view','c'),
        ger.event('p2','view','d'),

        ger.event('p3','view','a'),
        ger.event('p3','view','c')
      ])
      .then(-> ger.recommendations_for_person('p1', 'view'))
      .then((item_weights) ->
        item_weights[0].thing.should.equal 'a'
        item_weights[1].thing.should.equal 'c'
        item_weights[2].thing.should.equal 'd'
        
      )

describe 'similar things', ->
  it 'should take a thing action and return similar things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','thing1'),
        ger.event('p1','action1','thing2'),
      ])
      .then(-> ger.similar_things_for_action('thing1', 'action1'))
      .then((things) -> ('thing2' in things).should.equal true)
     
describe 'similar people', ->
  it 'should take a person action and return similar people', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','thing1'),
        ger.event('p2','action1','thing1'),
      ])
      .then(-> ger.similar_people_for_action('p1', 'action1'))
      .then(( people) -> ('p2' in people).should.equal true)

describe 'weighted_similar_things', ->
  it 'should take a person and return promise for an ordered list of similar things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','a'),
        ger.event('p1','action1','b'),
        ger.event('p1','action1','c'),

        ger.event('p2','action1','a'),
        ger.event('p2','action1','b'),

        ger.event('p3','action1','d')
      ])
      .then(-> ger.weighted_similar_things('a'))
      .then((things) ->
        #a actions p1, p2, and b actions p1 and p2, and c actions p1
        #a is 
        things.map['b'].should.equal 1
        things.map['c'].should.equal 1/2
        things.ordered_list.length.should.equal 3
      )

describe 'weighted_similar_people', ->
  it 'should return a list of similar people weighted with jaccard distance', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.weighted_similar_people('p1'))
      .then((people) ->

        people.map['p1'].should.equal 1
        people.map['p3'].should.equal 1
        people.map['p2'].should.equal 1/2
        people.ordered_list.length.should.equal 3
      )

  it 'should handle a non associated event on person', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','not')
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.weighted_similar_people('p1'))
      .then((people) ->
        people.ordered_list[0][0].should.equal 'p1'
        people.ordered_list[1][0].should.equal 'p3'
        compare_floats( people.ordered_list[1][1], 2/3).should.equal true
        people.ordered_list[2][0].should.equal 'p2'
        compare_floats( people.ordered_list[2][1],1/3).should.equal true
        people.ordered_list.length.should.equal 3
      )


describe 'setting action weights', ->

  it 'should work getting all weights', ->
    init_ger()
    .then (ger) ->
      ger.action('buybuy', 10)
      .then( (val) -> ger.action('viewview', 1))
      .then( ->
        bb.all([
          ger.event('p1', 'buybuy', 'a'),
          ger.event('p1', 'buybuy', 'b'),
          ger.event('p1', 'buybuy', 'c'),
          ])
      )
      .then(-> ger.esm.get_ordered_action_set_with_weights())
      .then((actions) -> 
        actions[0].key.should.equal "buybuy"
        actions[0].weight.should.equal 10
        actions[1].key.should.equal "viewview"
        actions[1].weight.should.equal 1
      )

  it 'should work multiple at the time', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('viewview', 1),
        ger.action('buybuy', 10),
      ])
      .then(-> ger.event('p1', 'buybuy', 'a'))
      .then(-> ger.get_action('buybuy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should override existing weight', ->
    init_ger()
    .then (ger) ->
      ger.event('p1', 'buy', 'a')
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should add the action with a weight to a sorted set', ->
    init_ger()
    .then (ger) ->
      ger.action('buy', 10)
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should default the action weight to 1', ->
    init_ger()
    .then (ger) ->
      ger.action('buy')
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 1)
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)
