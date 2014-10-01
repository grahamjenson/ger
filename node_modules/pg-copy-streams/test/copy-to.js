var assert = require('assert')
var gonna = require('gonna')

var _ = require('lodash')
var async = require('async')
var concat = require('concat-stream')
var pg = require('pg.js')

var copy = require('../').to

var client = function() {
  var client = new pg.Client()
  client.connect()
  return client
}

var testConstruction = function() {
  var txt = 'COPY (SELECT * FROM generate_series(0, 10)) TO STDOUT'
  var stream = copy(txt, {highWaterMark: 10})
  assert.equal(stream._readableState.highWaterMark, 10, 'Client should have been set with a correct highWaterMark.')
}

testConstruction()

var testRange = function(top) {
  var fromClient = client()
  var txt = 'COPY (SELECT * from generate_series(0, ' + (top - 1) + ')) TO STDOUT'

  var stream = fromClient.query(copy(txt))
  var done = gonna('finish piping out', 1000, function() {
    fromClient.end()
  })

  stream.pipe(concat(function(buf) {
    var res = buf.toString('utf8')
    var expected = _.range(0, top).join('\n') + '\n'
    assert.equal(res, expected)
    assert.equal(stream.rowCount, top, 'should have rowCount ' + top + ' but got ' + stream.rowCount)
    done()
  }))
}

testRange(10000)

var testLeak = function(rounds) {
  var fromClient = client()
  var txt = 'COPY (SELECT 10) TO STDOUT'

  var runStream = function(num, callback) {
    var stream = fromClient.query(copy(txt))
    stream.on('data', function(data) {
      // Just throw away the data.
    })
    stream.on('end', callback)
    stream.on('error', callback)
  }

  async.timesSeries(rounds, runStream, function(err) {
    assert.equal(err, null)
    assert.equal(fromClient.connection.stream.listeners('close').length, 0)
    assert.equal(fromClient.connection.stream.listeners('data').length, 1)
    assert.equal(fromClient.connection.stream.listeners('end').length, 2)
    assert.equal(fromClient.connection.stream.listeners('error').length, 1)
    fromClient.end()
  })
}

testLeak(5)

var testInternalPostgresError = function() {
  var fromClient = client()
  // This attempts to make an array that's too large, and should fail.
  var txt = "COPY (SELECT asdlfsdf AS e) t) TO STDOUT"

  var runStream = function(callback) {
    var stream = fromClient.query(copy(txt))
    stream.on('data', function(data) {
      // Just throw away the data.
    })
    stream.on('error', callback)
  }

  runStream(function(err) {
    assert.notEqual(err, null)
    fromClient.end()
  })
}

testInternalPostgresError()
