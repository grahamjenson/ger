chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_algorithms = require('../lib/algorithms')

describe 'event', ->
  it 'should take a person action thing and return promise', (done) ->
    ger_algorithms.event('person','action','thing')
    .then(done, done)