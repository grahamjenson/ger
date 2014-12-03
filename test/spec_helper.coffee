chai = require 'chai'  
should = chai.should()

global.bb = require 'bluebird'
bb.Promise.longStackTraces();

g = require('../ger')
global.GER = g.GER

global.PsqlESM = g.PsqlESM
global.MemESM = g.MemESM

global.fs = require('fs');
global.path = require('path')
global.Readable = require('stream').Readable;

global.moment = require "moment"

global.knex = g.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})


global.default_esm = PsqlESM

global.esms = [{esm: PsqlESM, name: 'PSQLESM'}, {esm: MemESM, name: 'BasicInMemoryESM'}]

global.init_esm = (ESM = global.default_esm, namespace = 'public') ->
  #in
  esm = new ESM(namespace, {knex: knex})
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> esm.destroy())
  .then( -> esm.initialize())
  .then( -> esm)

global.init_ger = (ESM = global.default_esm, namespace = 'public', options = {}) ->
  init_esm(ESM, namespace).then( (esm) -> new GER(esm, options))

global.compare_floats = (f1,f2) ->
  Math.abs(f1 - f2) < 0.00001

global.sample = (list) ->
  v = list[Math.floor(Math.random()*list.length)]
  v