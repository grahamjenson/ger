chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER

describe 'event', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    ger.event('person','action','thing')

  it 'should add the action to the set of actions', ->
    ger = new GER
    sinon.stub(ger, 'add_action')
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_action)
        