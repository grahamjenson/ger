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

Readable = require('stream').Readable;

knex = g.knex
  client: 'pg',
  connection: 
    host: '127.0.0.1', 
    user : 'root', 
    password : 'abcdEF123456', 
    database : 'ger_test'

create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> PsqlESM.drop_tables(knex))
  .then( -> PsqlESM.init_tables(knex))
  .then( -> psql_esm)

init_ger = ->
  create_psql_esm().then( (esm) -> new GER(esm))

describe "person exploits,", ->
  it "a single persons mass interaction should not outweigh 'real' interations", ->
    init_ger()
    .then (ger) ->
      rs = new Readable();
      for x in [1..100]
        rs.push("bad_person,view,t1,#{new Date().toISOString()},\n");
        rs.push("bad_person,buy,t1,#{new Date().toISOString()},\n");
      rs.push(null);
      ger.bootstrap(rs)
      .then( ->
        bb.all([
          ger.action('buy'),
          ger.action('view'),
          ger.event('real_person', 'view', 't1')
        ])
      )
      .then( ->
        ger.recommendations_for_person('real_person', 'buy')
      )
      .then( (recs) ->
        #real_person is similar to real_person 1, and bad_person 1
        #bad_person has bought nothing and bad_person has bought t1
        #real person to t1 is 0, bad_person to t1 is 1
        #t1 = (bad_person t1)/(real_person + bad_person) 
        recs[0].thing.should.equal 't1'
        recs[0].weight.should.equal 1/2
      )