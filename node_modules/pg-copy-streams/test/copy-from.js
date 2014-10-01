var assert = require('assert')
var gonna = require('gonna')

var concat = require('concat-stream')
var _ = require('lodash')
var pg = require('pg.js')

var copy = require('../').from

var client = function() {
  var client = new pg.Client()
  client.connect()
  return client
}

var testConstruction = function() {
  var highWaterMark = 10
  var stream = copy('COPY numbers FROM STDIN', {highWaterMark: 10, objectMode: true})
  for(var i = 0; i < highWaterMark * 1.5; i++) {
    stream.write('1\t2\n')
  }
  assert(!stream.write('1\t2\n'), 'Should correctly set highWaterMark.')
}

testConstruction()

var testRange = function(top) {
  var fromClient = client()
  fromClient.query('CREATE TEMP TABLE numbers(num int, bigger_num int)')

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
      //console.log('found ', res.rows.length, 'rows')
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
