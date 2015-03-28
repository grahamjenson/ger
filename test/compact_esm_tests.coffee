ns = global.default_namespace

describe "compact_database_thing_action_limit", ->
  it 'should truncate events on a thing to the set limit', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','t1')
        ger.event(ns, 'p2','view','t1')
        ger.event(ns, 'p3','view','t1')

        ger.event(ns, 'p1','view','t2')
        ger.event(ns, 'p2','view','t2')
      ])
      .then( ->
        ger.count_events(ns)
      )
      .then( (count) ->
        count.should.equal 5
      )
      .then( ->
        ger.compact_database(ns, compact_database_thing_action_limit: 2, actions: ['view'])
      )
      .then( ->
        ger.compact_database(ns, compact_database_thing_action_limit: 2, actions: ['view'])
      )
      .then( ->
        ger.count_events(ns)
      )
      .then( (count) ->
        count.should.equal 4
      )

describe "compact_database_person_action_limit", ->
  it 'should truncate events by a person to the set limit', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','t1')
        ger.event(ns, 'p1','view','t2')
        ger.event(ns, 'p1','view','t3')
        ger.event(ns, 'p1','view','t4')
        ger.event(ns, 'p1','view','t5')

        ger.event(ns, 'p2','view','t2')
        ger.event(ns, 'p2','view','t3')
      ])
      .then( ->
        ger.count_events(ns)
      )
      .then( (count) ->
        count.should.equal 7
      )
      .then( ->
        ger.compact_database(ns, compact_database_person_action_limit: 2, actions: ['view'])
      )
      .then( ->
        ger.compact_database(ns, compact_database_person_action_limit: 2, actions: ['view'])
      )
      .then( ->
        ger.count_events(ns)
      )
      .then( (count) ->
        count.should.equal 4
      )



