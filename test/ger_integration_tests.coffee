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

describe 'ordered_similar_people', ->
  it 'should take a person action thing and return promise for an ordered list of similar people', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','a'),
      ger.event('p2','action1','a'),
      ger.event('p3','action1','a'),

      ger.event('p1','action1','b'),
      ger.event('p3','action1','b'),

      ger.event('p4','action1','d')
    ])
    .then(-> ger.ordered_similar_people('p1'))
    .then((people) ->
      people[0].person.should.equal 'p3'
      people[1].person.should.equal 'p2'
      people.length.should.equal 2
    )

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

