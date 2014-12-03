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
