Errors = {}

class NamespaceDoestNotExist extends Error
  constructor: () ->
    super()
    @name = "NamespaceDoestNotExist"
    @message = "namespace does not exist"
    Error.captureStackTrace(this, NamespaceDoestNotExist)

Errors.NamespaceDoestNotExist = NamespaceDoestNotExist

module.exports = Errors;