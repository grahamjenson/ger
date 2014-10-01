var assert = require('assert')
var gonna = require('gonna')

var async = require('async')
var concat = require('concat-stream')
var _ = require('lodash')
var pg = require('pg.js')

var from = require('../').from
var to = require('../').to

var testBinaryCopy = function() {
  var client = function() {
    var client = new pg.Client()
    client.connect()
    return client
  }

  var fromClient = client()
  var toClient = client()

  queries = [
    'DROP TABLE IF EXISTS data',
    'CREATE TABLE IF NOT EXISTS data (num BIGINT, word TEXT)',
    'INSERT INTO data (num, word) VALUES (1, \'hello\'), (2, \'other thing\'), (3, \'goodbye\')',
    'DROP TABLE IF EXISTS data_copy',
    'CREATE TABLE IF NOT EXISTS data_copy (LIKE data INCLUDING ALL)'
  ]

  async.eachSeries(queries, _.bind(fromClient.query, fromClient), function(err) {
    assert.ifError(err)

    var fromStream = fromClient.query(to('COPY (SELECT * FROM data) TO STDOUT BINARY'))
    var toStream = toClient.query(from('COPY data_copy FROM STDIN BINARY'))

    runStream = function(callback) {
      fromStream.on('error', callback)
      toStream.on('error', callback)
      toStream.on('finish', callback)
      fromStream.pipe(toStream)
    }
    runStream(function(err) {
      assert.ifError(err)

      toClient.query('SELECT * FROM data_copy ORDER BY num', function(err, res){
        assert.equal(res.rowCount, 3, 'expected 3 rows but got ' + res.rowCount)
        assert.equal(res.rows[0].num, 1)
        assert.equal(res.rows[0].word, 'hello')
        assert.equal(res.rows[1].num, 2)
        assert.equal(res.rows[1].word, 'other thing')
        assert.equal(res.rows[2].num, 3)
        assert.equal(res.rows[2].word, 'goodbye')
        queries = [
          'DROP TABLE data',
          'DROP TABLE data_copy'
        ]
        async.each(queries, _.bind(fromClient.query, fromClient), function(err) {
          assert.ifError(err)
          fromClient.end()
          toClient.end()
        })
      })
    })
  })
}

testBinaryCopy()
