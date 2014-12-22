describe '#get_jaccard_distances_between_people', ->
  it 'should take a since, return recent as well', ->
    init_esm(PsqlESM)
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
    init_esm(PsqlESM)
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
    init_esm(PsqlESM)
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

describe "#bootstrap", ->
  it 'should not exhaust the pg connections'

describe "action cache", ->
  it 'should cache the action and invalidate when action changes', ->
    init_esm(PsqlESM)
    .then (esm) ->
      esm.set_action_weight('view', 1)
      .then( ->
        (esm.action_cache == null).should.equal true
        esm.get_actions()
      )
      .then( (actions) ->
        esm.action_cache.should.equal actions
        actions[0].key.should.equal 'view'
        actions[0].weight.should.equal 1
      )
      .then( ->
        esm.get_actions()
      )
      .then( (actions) ->
        esm.action_cache.should.equal actions
        esm.set_action_weight('view', 2)
      )
      .then( (exists) ->
        (esm.action_cache == null).should.equal true
      )

describe "find_similar_people", ->
  it 'should order by persons activity DATE (NOT DATETIME) then by COUNT', ->
    init_esm(PsqlESM)
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)

        esm.add_event('p1','view','t1', {created_at: new Date(2014, 6, 6, 13, 1)})
        esm.add_event('p1','view','t4', {created_at: new Date(2014, 6, 6, 13, 1)})
        esm.add_event('p1','view','t2', {created_at: new Date(2014, 6, 6, 13, 30)})

        #t3 is more important as it has more recently been seen
        esm.add_event('p1','view','t3', {created_at: new Date(2014, 6, 7, 13, 0)})

        #Most recent person ordered first
        esm.add_event('p4','view','t3')
        esm.add_event('p4','buy','t1')

        #ordered second as most similar person
        esm.add_event('p2','view','t1')
        esm.add_event('p2','buy','t1')
        esm.add_event('p2','view','t4')

        #ordered third equal as third most similar people
        esm.add_event('p3','view','t2')
        esm.add_event('p3','buy','t2')
      ])
      .then( ->
        esm.find_similar_people('p1', ['view', 'buy'], 'buy')
      )
      .then( (people) ->
        people[0].should.equal 'p4'
        people[1].should.equal 'p2'
        people[2].should.equal 'p3'
        people.length.should.equal 3
      )

describe "get_active_things", ->
  it 'should return an ordered list of the most active things', ->
    init_esm(PsqlESM)
    .then (esm) ->
      bb.all([
        esm.add_event('p1','view','t1')
        esm.add_event('p1','view','t2')
        esm.add_event('p1','view','t3')

        esm.add_event('p2','view','t2')
        esm.add_event('p2','view','t3')

        esm.add_event('p3','view','t3')
      ])
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.get_active_things()
      )
      .then( (things) ->
        things[0].should.equal 't3'
        things[1].should.equal 't2'
      )

describe "get_active_people", ->
  it 'should work when noone is there', ->
    init_esm(PsqlESM)
    .then( (esm) ->
      esm.add_event('p1','view','t1')
      .then(-> esm.vacuum_analyze())
      .then( -> esm.get_active_people())
    )

  it 'should return an ordered list of the most active people', ->
    init_esm(PsqlESM)
    .then (esm) ->
      bb.all([
        esm.add_event('p1','view','t1')
        esm.add_event('p1','view','t2')
        esm.add_event('p1','view','t3')

        esm.add_event('p2','view','t2')
        esm.add_event('p2','view','t3')
      ])
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.get_active_people()
      )
      .then( (people) ->
        people[0].should.equal 'p1'
        people[1].should.equal 'p2'
      )

describe '#compact method', ->
  it 'should not fail with no people and/or no actions', ->
    init_esm()
    .then (esm) ->
      bb.all([])
      .then( ->
        esm.truncate_people_per_action([], 1)
      )
      .then( ->
        esm.truncate_people_per_action(['p1'], 1)
      )
