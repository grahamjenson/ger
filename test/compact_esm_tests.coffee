describe "compact_database_thing_action_limit", ->
  it 'should truncate events on a thing to the set limit', ->
    init_ger(default_esm, 'public', compact_database_thing_action_limit: 2)
    .then (ger) ->
      bb.all([
        ger.action('view')
        ger.event('p1','view','t1')
        ger.event('p2','view','t1')
        ger.event('p3','view','t1')

        ger.event('p1','view','t2')
        ger.event('p2','view','t2')
      ])
      .then( ->
        ger.count_events()
      )
      .then( (count) ->
        count.should.equal 5
      )
      .then( ->
        ger.compact_database()
      )
      .then( ->
        ger.compact_database()
      )
      .then( ->
        ger.count_events()
      )
      .then( (count) ->
        count.should.equal 4
      )

describe "compact_database_person_action_limit", ->
  it 'should truncate events by a person to the set limit', ->
    init_ger(default_esm, 'public', compact_database_person_action_limit: 2)
    .then (ger) ->
      bb.all([
        ger.action('view', 1)
        ger.event('p1','view','t1')
        ger.event('p1','view','t2')
        ger.event('p1','view','t3')
        ger.event('p1','view','t4')
        ger.event('p1','view','t5')

        ger.event('p2','view','t2')
        ger.event('p2','view','t3')
      ])
      .then( ->
        ger.count_events()
      )
      .then( (count) ->
        count.should.equal 7
      )
      .then( ->
        ger.compact_database()
      )
      .then( ->
        ger.compact_database()
      )
      .then( ->
        ger.count_events()
      )
      .then( (count) ->
        count.should.equal 4
      )



