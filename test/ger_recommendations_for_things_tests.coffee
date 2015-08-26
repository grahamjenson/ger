ns = global.default_namespace

describe 'recommending for a thing', ->
  it 'max_thing_recommendations works never returns null weight', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
        ger.event(ns, 'p1','view','c', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}, max_thing_recommendations: 1))
      .then((recs) ->

        recs = recs.recommendations
        for r in recs
          if r.weight != 0
            (!!r.weight).should.equal true
      )

  it 'should not recommend the same thing', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 2}))
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



  it 'should not just recommend the popular things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','b', expires_at: tomorrow),
        ger.event(ns, 'p3','view','a', expires_at: tomorrow),
        ger.event(ns, 'p3','view','c', expires_at: tomorrow),
        ger.event(ns, 'p4','view','c', expires_at: tomorrow),
        ger.event(ns, 'p5','view','c', expires_at: tomorrow),
        ger.event(ns, 'p6','view','c', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
      .then((recs) ->
        # a and b are very similar as they have 
        recs = recs.recommendations
        recs.length.should.equal 2
        recs[0].thing.should.equal 'b'
        recs[1].thing.should.equal 'c'
        recs[0].weight.should.be.greaterThan(recs[1].weight)
      )


