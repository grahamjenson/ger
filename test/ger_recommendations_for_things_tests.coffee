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
        recs[0].thing.should.equal 'b'
        recs.length.should.equal 1
      )


