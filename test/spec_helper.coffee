chai = require 'chai'
should = chai.should()

global._ = require 'lodash'

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

global._knex = g.knex({client: 'pg', pool: {min: 5, max: 20}, connection: {host: '127.0.0.1', user : 'postgres', password : 'postgres', database : 'ger_test'}})

#global.default_esm = PsqlESM
global.default_esm = PsqlESM

global.esms = [{esm: PsqlESM, name: 'PSQLESM'}, {esm: MemESM, name: 'BasicInMemoryESM'}]

global.default_namespace = 'default'

global.yesterday = moment().subtract(1, 'days')
global.today = moment()
global.tomorrow = moment().add(1, 'days')
global.next_week = moment().add(7, 'days')

global.new_esm = (ESM)->
  esm = new ESM({knex: _knex})

global.init_esm = (ESM = global.default_esm, namespace = global.default_namespace) ->
  #in
  esm = new_esm(ESM)
  #drop the current tables, reinit the tables, return the esm
  bb.try(-> esm.destroy(namespace))
  .then( -> esm.initialize(namespace))
  .then( -> esm)

global.init_ger = (ESM = global.default_esm, namespace = global.default_namespace) ->
  init_esm(ESM, namespace).then( (esm) -> new GER(esm))

global.compare_floats = (f1,f2) ->
  Math.abs(f1 - f2) < 0.00001

global.sample = _.sample
