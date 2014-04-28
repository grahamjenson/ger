chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER
q = require 'q'

describe 'similar people', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','thing1'),
      ger.event('p2','action1','thing1'),
    ])
    .then(-> ger.similar_people_for_action('p1', 'action1'))
    .then((people) -> ('p2' in people).should.equal true)


describe 'similarity between people', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','viewed','a'),
      ger.event('p1', 'viewed', 'b'),
      ger.event('p1', 'viewed', 'c'),
      ger.event('p2','viewed','a'),
      ger.event('p2','viewed','b'),
      ger.event('p2','viewed','d')
    ])
    .then(-> ger.similarity('p1', 'p2'))
    .then((sim) -> sim.should.equal .5)

