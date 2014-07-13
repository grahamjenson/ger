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


create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(-> psql_esm.drop_tables())
  .then( -> psql_esm.init_tables())
  .then( -> psql_esm)


create_store_esm = ->
  q.fcall( -> new MemoryESM())

init_ger = ->
  create_psql_esm().then( (esm) -> new GER(esm))

describe 'performance tests', ->


  it 'adding 1000 events takes so much time', ->
    console.log ""
    console.log ""
    console.log "####################################################"
    console.log "################# Performance Tests ################"
    console.log "####################################################"
    console.log ""
    console.log ""
    this.timeout(5000);
    init_ger()
    .then (ger) ->
      st = new Date().getTime()
      actions = ["buy", "like", "view"]
      promises = []
      for x in [1..1000]
        action = actions[Math.floor(Math.random()*actions.length)];
        promises.push ger.set_action_weight(action , 10)
      q.all(promises)
      .then(->
        et = new Date().getTime()
        time = et-st
        pe = time/1000
        console.log "#{pe}ms per set action"
      )
      .then( ->
        console.log ""
        console.log ""
        console.log "####################################################"
        console.log "################# END OF Performance Tests #########"
        console.log "####################################################"
        console.log ""
        console.log ""
      )
