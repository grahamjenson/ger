chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_algorithms = require('../lib/algorithms')

describe 'event', ->
  it 'should takes a person verb thing and return promise', (done) ->
    ger_algorithms.event('person','verb','thing')
    .then(done, done)