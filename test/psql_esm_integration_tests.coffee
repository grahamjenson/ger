chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

path = require 'path'

PsqlESM = require('../lib/psql_esm')

bb = require 'bluebird'
bb.Promise.longStackTraces();

fs = require('fs');

Readable = require('stream').Readable;

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})


init_esm = (limits = {}) ->
  #in
  psql_esm = new PsqlESM(knex, 'public', limits)
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> psql_esm.drop_tables())
  .then( -> psql_esm.init_tables())
  .then( -> psql_esm)

describe "find_event", ->
  it "should return null if no event matches", ->
    init_esm()
    .then (esm) ->
      esm.find_event('p','a','t')
      .then( (event) ->
        true.should.equal event == null
      )

  it "should return an event if one matches", ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.find_event('p','a','t')
      )
      .then( (event) ->
        event.person.should.equal 'p' 
        event.action.should.equal 'a'
        event.thing.should.equal 't'
      )

describe "get_people_that_actioned_things", ->
  it "should select people ordered by created_at", ->
    now = new Date().toISOString()
    ages_ago = new Date(0).toISOString()
    init_esm({upper_limit: 10})
    .then (esm) ->
      promises = (esm.add_event("p#{i}",'a','t', { created_at: now }) for i in [0...10])
      promises.push esm.add_event("old_person",'a','t', { created_at: ages_ago })
      bb.all(promises)
      .then( ->
        esm.get_people_that_actioned_things(['t'], 'a')
      )
      .then( (people) ->
        ("old_person" not in people).should.equal true
      )


describe "remove_expired_events", ->
  it "removes the events passed their expiry date", ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t', {expires_at: new Date(0).toISOString()} )
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 1
        esm.remove_expired_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 0 )

  it "does not remove events that have no expiry date or future date", ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'),  esm.add_event('p2','a','t', {expires_at:new Date(2050,10,10)}), esm.add_event('p3','a','t', {expires_at: new Date(0).toISOString()})])
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 3
        esm.remove_expired_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 2 
        esm.find_event('p2','a','t')
      )
      .then( (event) ->
        event.expires_at.getTime().should.equal (new Date(2050,10,10)).getTime() 
      )

describe "remove_non_unique_events", ->
  it "remove all events that are not unique", ->
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 2
        esm.remove_non_unique_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 1 )

  it "removes events that have a older created_at", ->
    init_esm()
    .then (esm) ->    
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 2
        esm.remove_non_unique_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 1
        esm.find_event('person','action','thing')
      )
      .then( (event) ->
        expected_created_at = new Date('2014-01-01')
        event.created_at.getFullYear().should.equal expected_created_at.getFullYear() 
      )

describe "remove_superseded_events", ->
  it "Remove events that have been superseded events", ->
    #e.g. bob views a and bob redeems a, we can remove bob views a
describe "remove_excessive_user_events", ->
  it "find members with most events and truncate them down", ->

describe "remove_events_till_size", ->
  it "removes old events till there is only number_of_events left", ->
    init_esm()
    .then (esm) ->    
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 4
        esm.remove_events_till_size(2)
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 2
      )


describe "expires at", ->
  it 'should accept an expiry date', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('a', 1)
        esm.add_event('p','a','t', new Date().toISOString())
      ])
      .then( ->
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_action('a')
      )
      .then( (has_action) ->
        has_action.should.equal true
      )

bootstream = ->
  rs = new Readable();
  rs.push('person,action,thing,2014-01-01,\n');
  rs.push('person,action,thing1,2014-01-01,\n');
  rs.push('person,action,thing2,2014-01-01,\n');
  rs.push(null);
  rs

describe "#bootstrap", ->

  it 'should not exhaust the pg connections'

  it 'should load a set cof events from a file into the database', -> 
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push('person,action,thing1,2014-01-01,\n');
      rs.push('person,action,thing2,2014-01-01,\n');
      rs.push(null);

      esm.bootstrap(rs)
      .then( (returned_count) -> bb.all([returned_count, esm.count_events()]))
      .spread( (returned_count, count) -> 
        count.should.equal 3
        returned_count.should.equal 3
      )

    
  it 'should load a set of events from a file into the database', ->
    init_esm()
    .then (esm) ->
      fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
      esm.bootstrap(fileStream)
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 3)

describe "Schemas for multitenancy", ->
  it "should have different counts for different schemas", ->
    psql_esm1 = new PsqlESM(knex, "schema1")
    psql_esm2 = new PsqlESM(knex, "schema2")

    bb.all([psql_esm1.drop_tables(),psql_esm2.drop_tables()])
    .then( -> bb.all([psql_esm1.init_tables(),psql_esm2.init_tables()]) )
    .then( ->
      bb.all([
        psql_esm1.add_event('p','a','t')
        psql_esm1.add_event('p1','a','t')

        psql_esm2.add_event('p2','a','t')
      ])
    )
    .then( ->
      bb.all([psql_esm1.count_events(), psql_esm2.count_events() ]) 
    )
    .spread((c1,c2) ->
      c1.should.equal 2
      c2.should.equal 1
    )

describe '#initial tables', ->
  it 'should have empty actions table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('actions')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 0
      )

  it 'should have empty events table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('events')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 0
      )

describe '#add_event', ->

  it 'should add the event to the events table', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_event('p','a', 't')
      )
      .then( (has_event) ->
        has_event.should.equal true
      )

describe 'set_action_weight', ->
  it 'should not overwrite if set to false', ->
    init_esm()
    .then (esm) ->
      esm.set_action_weight('a', 1)
      .then( ->
        esm.get_action_weight('a')
      )
      .then( (weight) ->
        weight.should.equal 1
        esm.set_action_weight('a', 10, false).then( -> esm.get_action_weight('a'))
      )
      .then( (weight) ->
        weight.should.equal 1
      )


describe '#get_ordered_action_set_with_weights', ->
  it 'should return actions with weights', ->
    init_esm()
    .then (esm) ->
      bb.all([ esm.set_action_weight('a2',1) , esm.add_event('p','a','t'), esm.add_event('p','a2','t')])
      .then( -> esm.set_action_weight('a',10))
      .then( -> esm.get_ordered_action_set_with_weights())
      .then( (action_weights) ->
        action_weights[0].key.should.equal 'a'
        action_weights[0].weight.should.equal 10
        action_weights[1].key.should.equal 'a2'
        action_weights[1].weight.should.equal 1
      ) 


describe '#get_things_that_actioned_person', ->
  it 'should return list of things', ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p','a','t'),esm.add_event('p','a','t1')])
      .then( -> esm.get_things_that_actioned_person('p','a'))
      .then( (things) ->
        ('t' in things).should.equal true
        ('t1' in things).should.equal true
      ) 

describe '#get_jaccard_distances_between_people', ->
  it 'should return an object of people to jaccard distance', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','a','t1'),
        esm.add_event('p1','a','t2'),
        esm.add_event('p2','a','t2')
      ])
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .then( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )     

  it 'should not be effected by multiple events of the same type', ->
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('p1,a,t1,2013-01-01,\n');
      rs.push('p1,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .then( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )   

describe '#things_people_have_actioned', ->
  it 'should return list of things that people have actioned', ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'),esm.add_event('p2','a','t1')])
      .then( -> esm.things_people_have_actioned('a',['p1','p2']))
      .then( (people_things) ->
        people_things['p1'].should.contain 't'
        people_things['p1'].length.should.equal 1
        people_things['p2'].should.contain 't1'
        people_things['p2'].length.should.equal 1
      ) 

  it 'should return the same item for different people', ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'), esm.add_event('p2','a','t')])
      .then( -> esm.things_people_have_actioned('a',['p1','p2']))
      .then( (people_things) ->
        people_things['p1'].should.contain 't'
        people_things['p1'].length.should.equal 1
        people_things['p2'].should.contain 't'
        people_things['p2'].length.should.equal 1
      ) 
