chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER

describe 'similar users', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    ger.event('person','action','thing')


