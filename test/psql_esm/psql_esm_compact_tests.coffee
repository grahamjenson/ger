describe "find_similar_people", ->
  it 'should order by persons activity DATE (NOT DATETIME) then by COUNT', ->
    init_esm()
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
    init_esm()
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
    init_esm()
    .then( (esm) ->
      esm.add_event('p1','view','t1')
      .then(-> esm.vacuum_analyze())
      .then( -> esm.get_active_people())
    )

  it 'should return an ordered list of the most active people', ->
    init_esm()
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