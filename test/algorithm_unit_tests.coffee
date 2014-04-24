chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_algorithms = require('../lib/algorithms')
ger_models = require('../lib/models')

KVStore = ger_models.KVStore

