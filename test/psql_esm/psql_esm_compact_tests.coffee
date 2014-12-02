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