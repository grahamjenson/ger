ger_tests = (ESM) ->
  ns = global.default_namespace

  describe 'recommending for a thing', ->
    it 'works never returns null weight', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns, 'p1','view','a', expires_at: tomorrow),
          ger.event(ns, 'p1','view','b', expires_at: tomorrow),
          ger.event(ns, 'p1','view','c', expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
        .then((recs) ->

          recs = recs.recommendations
          for r in recs
            if r.weight != 0
              (!!r.weight).should.equal true
        )

    it 'should not recommend the same thing', ->
      init_ger(ESM)
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
      init_ger(ESM)
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


    it 'should not more highly rate bad recommendations', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns, 'p1','view','a'),
          ger.event(ns, 'p2','view','a'),
          ger.event(ns, 'p3','view','a'),

          ger.event(ns, 'p1','view','c', expires_at: tomorrow),

          ger.event(ns, 'p2','view','b', expires_at: tomorrow),
          ger.event(ns, 'p3','view','b', expires_at: tomorrow),

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


    it 'should not just recommend the popular things', ->
      init_ger(ESM)
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


    describe 'thing exploits', ->
      it 'should not be altered by a single person doing the same thing a lot', ->
        init_ger(ESM)
        .then (ger) ->
          events = []
          for x in [1..100]
            events.push ger.event(ns, "bad_person",'view','t2', expires_at: tomorrow)
            events.push ger.event(ns, "bad_person",'buy','t2', expires_at: tomorrow)

          bb.all(events)
          .then( ->
            bb.all([
              ger.event(ns, 'bad_person', 'view', 't1')
              ger.event(ns, 'real_person', 'view', 't1')

              ger.event(ns, 'real_person', 'view', 't3', expires_at: tomorrow)
              ger.event(ns, 'real_person', 'buy', 't3', expires_at: tomorrow)

            ])
          )
          .then( ->
            ger.recommendations_for_thing(ns, 't1', actions: {buy:1, view:1})
          )
          .then((recs) ->
            item_weights = recs.recommendations
            temp = {}
            (temp[tw.thing] = tw.weight for tw in item_weights)
            temp['t2'].should.equal temp['t3']
          )



    it 'should not return any recommendations if none are there', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns, 'p1','view','a')
        ])
        .then(-> ger.recommendations_for_thing(ns, 'a',  actions: {view: 1}))
        .then((recs) ->
          recs.recommendations.length.should.equal 0

          throw "BAD Confidence #{recommendations_object.confidence}" if not _.isFinite(recs.confidence)
        )

    describe 'time_until_expiry', ->
      it 'should not return recommendations that will expire within time_until_expiry seconds', ->
        one_hour = 60*60
        one_day = 24*one_hour
        a1day = moment().add(1, 'days').format()
        a2days = moment().add(2, 'days').format()
        a3days = moment().add(3, 'days').format()

        init_ger(ESM)
        .then (ger) ->
          bb.all([
            ger.event(ns, 'p1','view','a'),
            ger.event(ns, 'p1','buy','x', expires_at: a1day),
            ger.event(ns, 'p1','buy','y', expires_at: a2days),
            ger.event(ns, 'p1','buy','z', expires_at: a3days)
          ])
          .then(-> ger.recommendations_for_thing(ns, 'a', time_until_expiry: (one_day + one_hour), actions: {view: 1, buy: 1}))
          .then((recs) ->
            recs = recs.recommendations
            recs.length.should.equal 2
            sorted_recs = [recs[0].thing, recs[1].thing].sort()
            sorted_recs[0].should.equal 'y'
            sorted_recs[1].should.equal 'z'
          )

    describe "confidence", ->
      it 'should return a confidence ', ->
        init_ger(ESM)
        .then (ger) ->
          bb.all([
            ger.event(ns, 'p1','a','t1'),
            ger.event(ns, 'p2','a','t2', expires_at: tomorrow),
          ])
          .then(-> ger.recommendations_for_thing(ns, 't1', actions: {a: 1}))
          .then((recs) ->
            recs.confidence.should.exist
            _.isFinite(recs.confidence).should.equal true
          )


    describe "weights", ->
      it "weights should determine the order of the recommendations", ->
        init_ger(ESM)
        .then (ger) ->
          bb.all([
            ger.event(ns, 'p1','view','a'),
            ger.event(ns, 'p2','buy','a'),

            ger.event(ns, 'p1','view','b', expires_at: tomorrow)

            ger.event(ns, 'p2','view','c', expires_at: tomorrow)
          ])
          .then(-> ger.recommendations_for_thing(ns, 'a', actions: {view: 1, buy: 1}))
          .then((recs) ->
            item_weights = recs.recommendations
            item_weights.length.should.equal 2
            item_weights[0].weight.should.equal item_weights[1].weight

            ger.recommendations_for_thing(ns, 'a', actions: {view: 1, buy: 2})
          )
          .then((recs) ->
            item_weights = recs.recommendations
            item_weights[0].weight.should.be.greaterThan item_weights[1].weight
            item_weights[0].thing.should.equal 'c'
            item_weights[1].thing.should.equal 'b'
          )

module.exports = ger_tests;