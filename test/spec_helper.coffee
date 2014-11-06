chai = require 'chai'  
should = chai.should()

global.bb = require 'bluebird'
bb.Promise.longStackTraces();

g = require('../ger')
global.GER = g.GER

global.PsqlESM = g.PsqlESM

global.fs = require('fs');
global.path = require('path')
global.Readable = require('stream').Readable;

global.moment = require "moment"

global.knex = g.knex
  client: 'pg',
  #debug: true
  connection: 
    host: '127.0.0.1', 
    user : 'root', 
    password : 'abcdEF123456', 
    database : 'ger_test'


global.init_esm = () ->
  #in
  psql_esm = new PsqlESM(knex, 'public')
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> psql_esm.drop_tables())
  .then( -> psql_esm.init_tables())
  .then( -> psql_esm)

global.init_ger = (options = {}) ->
  init_esm().then( (esm) -> new GER(esm, options))

global.compare_floats = (f1,f2) ->
  Math.abs(f1 - f2) < 0.00001

global.sample = (list) ->
  v = list[Math.floor(Math.random()*list.length)]
  v