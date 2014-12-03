


describe "filter_things_by_previous_actions", ->
  it 'should filter things a person has done before', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
      ]) 
      .then( ->
        esm.filter_things_by_previous_actions('p1', ['t1','t2'], ['view'])
      )
      .then( (things) ->
        things.length.should.equal 1
        things[0].should.equal 't2'
      )

  it 'should filter things only for given actions', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p1','buy','t2')
      ]) 
      .then( ->
        esm.filter_things_by_previous_actions('p1', ['t1','t2'], ['view'])
      )
      .then( (things) ->
        things.length.should.equal 1
        things[0].should.equal 't2'
      )     


bootstream = ->
  rs = new Readable();
  rs.push('person,action,thing,2014-01-01,\n');
  rs.push('person,action,thing1,2014-01-01,\n');
  rs.push('person,action,thing2,2014-01-01,\n');
  rs.push(null);
  rs

describe "#bootstrap", ->

  it 'should not exhaust the pg connections'

  it 'should load a set cof events from a file into the database', -> 
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push('person,action,thing1,2014-01-01,\n');
      rs.push('person,action,thing2,2014-01-01,\n');
      rs.push(null);

      esm.bootstrap(rs)
      .then( (returned_count) -> bb.all([returned_count, esm.count_events()]))
      .spread( (returned_count, count) -> 
        count.should.equal 3
        returned_count.should.equal 3
      )

    
  it 'should load a set of events from a file into the database', ->
    init_esm()
    .then (esm) ->
      fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
      esm.bootstrap(fileStream)
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 3)

describe "Schemas for multitenancy", ->
  it "should have different counts for different schemas", ->
    psql_esm1 = new PsqlESM("schema1", {knex: knex})
    psql_esm2 = new PsqlESM("schema2", {knex: knex})

    bb.all([psql_esm1.destroy(),psql_esm2.destroy()])
    .then( -> bb.all([psql_esm1.initialize(), psql_esm2.initialize()]) )
    .then( ->
      bb.all([
        psql_esm1.add_event('p','a','t')
        psql_esm1.add_event('p1','a','t')

        psql_esm2.add_event('p2','a','t')
      ])
    )
    .then( ->
      bb.all([psql_esm1.count_events(), psql_esm2.count_events() ]) 
    )
    .spread((c1,c2) ->
      c1.should.equal 2
      c2.should.equal 1
    )




describe 'set_action_weight', ->
  it 'should not overwrite if set to false', ->
    init_esm()
    .then (esm) ->
      esm.set_action_weight('a', 1)
      .then( ->
        esm.get_action_weight('a')
      )
      .then( (weight) ->
        weight.should.equal 1
        esm.set_action_weight('a', 10, false).then( -> esm.get_action_weight('a'))
      )
      .then( (weight) ->
        weight.should.equal 1
      )




describe '#get_jaccard_distances_between_people', ->
  it 'should take a since, return recent as well', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','a','t1'),
        esm.add_event('p1','a','t2'),
        esm.add_event('p2','a','t2'),
        esm.add_event('p2','a','t1', created_at: moment().subtract(5, 'days'))
      ])
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a'], 500, 2))
      .spread( (limit_distances, jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      ) 

  it 'should return an object of people to jaccard distance', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','a','t1'),
        esm.add_event('p1','a','t2'),
        esm.add_event('p2','a','t2')
      ])
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .spread( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )     

  it 'should not be effected by multiple events of the same type', ->
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('p1,a,t1,2013-01-01,\n');
      rs.push('p1,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .spread( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )
