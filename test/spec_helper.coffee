chai = require 'chai'
should = chai.should()

global._ = require 'underscore'

global.bb = require 'bluebird'
bb.Promise.longStackTraces();

g = require('../ger')
global.GER = g.GER

global.target_db = process.env.TARGET_DB || "pg"

global.PsqlESM = g.PsqlESM
global.MemESM = g.MemESM
global.RethinkDBESM = g.RethinkDBESM

global.fs = require('fs');
global.path = require('path')
global.Readable = require('stream').Readable;

global.moment = require "moment"

global.knex = g.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'postgres', password : 'postgres', database : 'ger_test'}})
global.r = g.r({ host: '127.0.0.1', port: 28015, db:'test', timeout: 120000, buffer:10 , max: 50})

#global.default_esm = PsqlESM
global.default_esm = PsqlESM

global.esms = [{esm: RethinkDBESM, name: 'RethinkDBESM'} ,{esm: PsqlESM, name: 'PSQLESM'}, {esm: MemESM, name: 'BasicInMemoryESM'}]

global.init_esm = (ESM = global.default_esm, namespace = 'default') ->
  #in
  esm = new ESM(namespace, {knex: knex, r: r})
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> esm.destroy())
  .then( -> esm.initialize())
  .then( -> esm)

global.init_ger = (ESM = global.default_esm, namespace = 'default', options = {}) ->
  init_esm(ESM, namespace).then( (esm) -> new GER(esm, options))

global.compare_floats = (f1,f2) ->
  Math.abs(f1 - f2) < 0.00001

global.sample = _.sample
