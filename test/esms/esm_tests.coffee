api_tests = require './esm_api_tests'
compact_tests = require './esm_compact_tests'
esm_errors = require './esm_errors'
esm_performance_tests = require './esm_performance_tests'

test_esm = (esm) ->
  describe "ESM TEST: #{esm.name}", ->
    api_tests(esm)
    compact_tests(esm)
    esm_errors(esm)
    esm_performance_tests(esm)

module.exports = test_esm;