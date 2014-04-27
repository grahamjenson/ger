chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER
q = require 'q'

describe 'similar users', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','thing1'),
      ger.event('p2','action1','thing1'),
    ])
    .then(-> ger.similar_people_for_action('p1', 'action1'))
    .then((people) -> ('p2' in people).should.equal true)



