var assert = require('assert')
var gonna = require('gonna')

var concat = require('concat-stream')
var _ = require('lodash')
var pg = require('pg.js')

var testRange = function(top) {
  var client = function() {
    var client = new pg.Client()
    client.connect()
    client.query('CREATE TEMP TABLE numbers(num int, bigger_num int)')
    return client
  }

  var fromClient = client()
  var copy = require('../').from


  var txt = 'COPY numbers FROM STDIN'

  var stream = fromClient.query(copy(txt))
  var rowEmitCount = 0
  stream.on('row', function() {
    rowEmitCount++
  })
  for(var i = 0; i < top; i++) {
    stream.write(Buffer('' + i + '\t' + i*10 + '\n'))
  }
  stream.end()
  var countDone = gonna('have correct count')
  stream.on('end', function() {
    fromClient.query('SELECT COUNT(*) FROM numbers', function(err, res) {
      assert.ifError(err)
      assert.equal(res.rows[0].count, top, 'expected ' + top + ' rows but got ' + res.rows[0].count)
      console.log('found ', res.rows.length, 'rows')
      countDone()
      var firstRowDone = gonna('have correct result')
      assert.equal(stream.rowCount, top, 'should have rowCount ' + top + ' ')
      fromClient.query('SELECT (max(num)) AS num FROM numbers', function(err, res) {
        assert.ifError(err)
        assert.equal(res.rows[0].num, top-1)
        firstRowDone()
        fromClient.end()
      })
    })
  })
}

testRange(1000)
