chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

MemoryESM = require('../lib/memory_esm')
PsqlESM = require('../lib/psql_esm')

GER = require('../ger').GER
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

create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(drop_tables)
  .then( -> psql_esm.init_database_tables())
  .then( -> psql_esm)

create_store_esm = ->
  q.fcall( -> new MemoryESM())

init_ger = ->
  create_psql_esm().then( (esm) -> new GER(esm))

describe 'adding events', ->
  it 'adding 1000 events takes so much time', ->
    this.timeout(5000);
    init_ger()
    .then (ger) ->
      console.log "START #{new Date()}"
      promises = []
      for x in [1..1000]
        promises.push ger.event('p1','buy','c')
      q.all(promises)
      .then(-> 
        console.log "Finished #{new Date()}"
      )