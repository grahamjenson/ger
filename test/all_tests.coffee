esm_tests = require './esms/esm_tests'
ger_tests = require './ger/ger_tests'

all_tests = (ESM) ->
  esm_tests(ESM)
  ger_tests(ESM)

module.exports = all_tests;