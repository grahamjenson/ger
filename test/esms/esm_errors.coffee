esm_tests = (ESM) ->
  ns = "default"

  describe 'no namespace error', ->
    it 'should initialize namespace', ->
      esm = new ESM({knex: _knex, r: _r})
      esm.add_event('not_a_namespace', 'p','a','t')
      .then( -> 
        throw "SHOULD NOT GET HERE"
      )
      .catch( GER.NamespaceDoestNotExist, (e) ->
        e.message.should.equal "namespace does not exist"
      )

for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)