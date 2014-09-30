chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

PsqlESM = require('../lib/psql_esm')

GER = require('../ger').GER
q = require 'q'

Readable = require('stream').Readable;

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})


create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(-> PsqlESM.drop_tables(knex))
  .then( -> PsqlESM.init_tables(knex))
  .then( -> psql_esm)

actions = ["buy", "like", "view"]
people = [1..10000]
things = [1..1000]

init_ger = ->
  create_psql_esm().then( (esm) -> new GER(esm))

sample = (list) ->
  v = list[Math.floor(Math.random()*list.length)]
  v
  
describe 'performance tests', ->

  it 'adding 1000 events takes so much time', ->
    console.log ""
    console.log ""
    console.log "####################################################"
    console.log "################# Performance Tests ################"
    console.log "####################################################"
    console.log ""
    console.log ""
    this.timeout(60000);
    init_ger()
    .then((ger) ->
      q.fcall( ->

        st = new Date().getTime()
        
        promises = []
        for x in [1..1000]
          promises.push ger.action(sample(actions) , sample([1..10]))
        q.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/1000
          console.log "#{pe}ms per action"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..500]
          promises.push ger.event(sample(people), sample(actions) , sample(things))
        q.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/500
          console.log "#{pe}ms per event"
        )
      )
      .then( ->
        st = new Date().getTime()

        rs = new Readable();
        for x in [1..20000]
          rs.push("#{sample(people)},#{sample(actions)},#{sample(things)},2014-01-01\n")
        rs.push(null);

        ger.bootstrap(rs)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/20000
          console.log "#{pe}ms per bootstrapped event"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..100]
          promises.push ger.ordered_similar_people(sample(people))
        q.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/100
          console.log "#{pe}ms per ordered_similar_people"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..100]
          promises.push ger.recommendations_for_person(sample(people), sample(actions))
        q.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/100
          console.log "#{pe}ms per recommendations_for_person"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..100]
          promises.push ger.recommendations_for_thing(sample(things), sample(actions))
        q.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/100
          console.log "#{pe}ms per recommendations_for_thing"
        )
      )
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
