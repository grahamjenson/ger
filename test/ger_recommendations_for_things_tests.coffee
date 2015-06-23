ns = global.default_namespace

describe 'recommending', ->
  it 'should recommend similar things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
      .then((recs) ->
        recs = recs.recommendations
        recs.length.should.equal 1
        recs[0].thing.should.equal 'b'
      )

  it 'should not recommend the same thing', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
      .then((recs) ->
        recs = recs.recommendations
        recs.length.should.equal 1
        recs[0].thing.should.equal 'b'
      )

  it 'doesnt return expired things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
        ger.event(ns, 'p1','view','c', expires_at: yesterday),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
      .then((recs) ->
        recs = recs.recommendations
        recs.length.should.equal 1
        recs[0].thing.should.equal 'b'
      )

  it 'should recommend things that are coupled', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','c', expires_at: tomorrow),
        ger.event(ns, 'p3','view','c', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
      .then((recs) ->
        # c is less coupled because people not looking at a are looking at c
        recs = recs.recommendations
        recs.length.should.equal 2
        recs[0].thing.should.equal 'b'
        recs[1].thing.should.equal 'c'
        recs[0].weight.should.be.greaterThan(recs[1].weight)
      )


