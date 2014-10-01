var CopyToQueryStream = require('./copy-to')

module.exports = {
  to: function(txt, options) {
    return new CopyToQueryStream(txt, options)
  },
  from: function (txt, options) {
    return new CopyStreamQuery(txt, options)
  }
}

var Transform = require('stream').Transform
var util = require('util')

var CopyStreamQuery = function(text, options) {
  Transform.call(this, options)
  this.text = text
  this._listeners = null
  this._copyOutResponse = null
  this.rowCount = 0
}

util.inherits(CopyStreamQuery, Transform)

CopyStreamQuery.prototype.submit = function(connection) {
  this.connection = connection
  connection.query(this.text)
}

var code = {
  H: 72, //CopyOutResponse
  d: 0x64, //CopyData
  c: 0x63 //CopyDone
}

var copyDataBuffer = Buffer([code.d])
CopyStreamQuery.prototype._transform = function(chunk, enc, cb) {
  this.push(copyDataBuffer)
  var lenBuffer = Buffer(4)
  lenBuffer.writeUInt32BE(chunk.length + 4, 0)
  this.push(lenBuffer)
  this.push(chunk)
  this.rowCount++
  cb()
}

CopyStreamQuery.prototype._flush = function(cb) {
  var finBuffer = Buffer([code.c, 0, 0, 0, 4])
  this.push(finBuffer)
  //never call this callback, do not close underlying stream
  //cb()
}

CopyStreamQuery.prototype.handleError = function(e) {
  this.emit('error', e)
}

CopyStreamQuery.prototype.handleCopyInResponse = function(connection) {
  this.pipe(connection.stream)
}

CopyStreamQuery.prototype.handleCommandComplete = function() {
  this.unpipe()
  this.emit('end')
}

CopyStreamQuery.prototype.handleReadyForQuery = function() {
}
