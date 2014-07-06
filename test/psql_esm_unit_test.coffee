chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

PsqlESM = require('../lib/psql_esm')

q = require 'q'

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})

drop_tables = ->
  q.all([knex.schema.hasTable('events'), knex.schema.hasTable('actions')])
  .spread( (has_events_table, has_actions_table) ->
    p = []
    p.push knex.schema.dropTable('events') if has_events_table
    p.push knex.schema.dropTable('actions') if has_actions_table
    q.all(p)
  )

init_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(drop_tables)
  .then( -> psql_esm.init_database_tables())
  .then( -> psql_esm)

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
  it 'should add the action to the actions table', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
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

describe 'add_action and set_action_weight', ->
  it 'should add action of weight 1, then set action should change it', ->
    init_esm()
    .then (esm) ->
      esm.add_action('a')
      .then( ->
        esm.get_action_weight('a')
      )
      .then( (weight) ->
        weight.should.equal 1
        esm.set_action_weight('a', 10).then( -> esm.get_action_weight('a'))
      )
      .then( (weight) ->
        weight.should.equal 10
      )

describe '#has_person_actioned_thing', ->
  it 'should return things people', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        q.all([esm.has_person_actioned_thing('p', 'a', 't'), esm.has_person_actioned_thing('p', 'a', 'not_t')])
      )
      .spread( (t1, t2) ->
        t1.should.equal true
        t2.should.equal false
      )