ger_tests = (ESM) ->
  ns = global.default_namespace

  describe '#list_namespaces', ->
    it 'should work', ->
      init_ger(ESM)
      .then (ger) ->
        ger.list_namespaces()
        .then((list) ->
          _.isArray(list).should.be.true
        )

  describe '#event', ->
    it 'should add events', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','c')
        ])
        .then(-> ger.count_events(ns))
        .then((count) ->
          count.should.equal 1
        )

  describe '#events', ->
    it 'should work same events', ->
      exp_date = new Date().toISOString()
      init_ger(ESM)
      .then (ger) ->
        ger.events([
          {namespace: ns, person: 'p1', action: 'a', thing: 't1'}
          {namespace: ns, person: 'p1', action: 'a', thing: 't2', created_at: new Date().toISOString()}
          {namespace: ns, person: 'p1', action: 'a', thing: 't3', expires_at: exp_date}
        ])
        .then(-> ger.count_events(ns))
        .then((count) ->
          count.should.equal 3
        )

  describe '#count_events', ->
    it 'should return 2 for 2 events', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','c'),
          ger.event(ns,'p1','view','c'),
        ])
        .then(-> ger.count_events(ns))
        .then((count) ->
          count.should.equal 2
        )

  describe 'recommendations_for_person', ->

    it 'should recommend basic things', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','a', expires_at: tomorrow),
          ger.event(ns,'p1','view','a', expires_at: tomorrow),

          ger.event(ns,'p2','view','a', expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p2', actions: {view:1, buy:1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights[0].thing.should.equal 'a'
          item_weights.length.should.equal 1
        )

    it 'should recommend things based on user history', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','a', expires_at: tomorrow),
          ger.event(ns,'p1','view','a', expires_at: tomorrow),

          ger.event(ns,'p2','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','buy','c', expires_at: tomorrow),
          ger.event(ns,'p2','buy','d', expires_at: tomorrow),

          ger.event(ns,'p3','view','a', expires_at: tomorrow),
          ger.event(ns,'p3','buy','c', expires_at: tomorrow)
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', actions: {view:1, buy:1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          #p1 is similar to (p1 by 1), p2 by .5, and (p3 by .5)
          #p1 buys a (a is 1), p2 and p3 buys c (.5 + .5=1) and p2 buys d (.5)
          items = (i.thing for i in item_weights)
          (items[0] == 'a' or items[0] == 'c').should.equal true
          items[2].should.equal 'd'
        )

    it 'should take a person and reccommend some things', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([

          ger.event(ns,'p1','view','a', expires_at: tomorrow),

          ger.event(ns,'p2','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','c', expires_at: tomorrow),
          ger.event(ns,'p2','view','d', expires_at: tomorrow),

          ger.event(ns,'p3','view','a', expires_at: tomorrow),
          ger.event(ns,'p3','view','c', expires_at: tomorrow)
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', actions: {view: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights[0].thing.should.equal 'a'
          item_weights[1].thing.should.equal 'c'
          item_weights[2].thing.should.equal 'd'

        )

    it 'should filter previously actioned things based on filter events option', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','a'),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', filter_previous_actions: ['buy'], actions: {buy: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 0
        )

    it 'should filter actioned things from other people', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','a', expires_at: tomorrow),
          ger.event(ns,'p1','buy','b', expires_at: tomorrow),
          ger.event(ns,'p2','buy','b', expires_at: tomorrow),
          ger.event(ns,'p2','buy','c', expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', filter_previous_actions: ['buy'], actions: {buy: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 1
          item_weights[0].thing.should.equal 'c'
        )

    it 'should filter previously actioned by someone else', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','buy','a', expires_at: tomorrow),
          ger.event(ns,'p2','buy','a', expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', filter_previous_actions: ['buy'], actions: {buy: 1, view: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 0
        )

    it 'should not filter non actioned things', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','buy','a', expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', filter_previous_actions: ['buy'], actions: {buy: 1, view: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 1
          item_weights[0].thing.should.equal 'a'
        )

    it 'should not break with weird names (SQL INJECTION)', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,"'p\n,1};","v'i\new","'a\n;", expires_at: tomorrow),
          ger.event(ns,"'p\n2};","v'i\new","'a\n;", expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, "'p\n,1};", actions: {"v'i\new": 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights[0].thing.should.equal "'a\n;"
          item_weights.length.should.equal 1
        )

    it 'should return the last_actioned_at date it was actioned at', ->

      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','a', expires_at: tomorrow),
          ger.event(ns,'p3','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','b', created_at: soon, expires_at: tomorrow),
          ger.event(ns,'p3','view','b', created_at: yesterday, expires_at: tomorrow),
        ])
        .then(-> ger.recommendations_for_person(ns, "p1", actions : {view: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 2
          item_weights[0].thing.should.equal "a"
          item_weights[1].thing.should.equal "b"
          (item_weights[1].last_actioned_at.replace(".","")).should.equal soon.format()
        )

    it 'should return the last_expires_at date it was expires at', ->


      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','a', expires_at: tomorrow),
          ger.event(ns,'p3','view','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','b', expires_at: tomorrow),
          ger.event(ns,'p2','view','b', expires_at: tomorrow),
          ger.event(ns,'p3','view','b', expires_at: next_week)
        ])
        .then(-> ger.recommendations_for_person(ns, "p1", actions : {view: 1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights.length.should.equal 2
          item_weights[0].thing.should.equal "a"
          (item_weights[0].last_expires_at.replace(".","")).should.equal tomorrow.format()
          item_weights[1].thing.should.equal "b"
          (item_weights[1].last_expires_at.replace(".","")).should.equal next_week.format()
        )

    it 'should people that contributed to recommendation', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p2','buy','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','a'),

          ger.event(ns,'p1','view','a'),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', actions: {view:1, buy:1}))
        .then((recommendations) ->
          item_weights = recommendations.recommendations
          item_weights[0].thing.should.equal 'a'
          item_weights[0].people.should.include 'p2'
          item_weights[0].people.length.should.equal 1
        )

    it 'should return neighbourhood', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([

          ger.event(ns,'p1','view','a'),

          ger.event(ns,'p2','buy','a', expires_at: tomorrow),
          ger.event(ns,'p2','view','a'),

          ger.event(ns,'p3','buy','b', expires_at: tomorrow),
          ger.event(ns,'p3','view','a'),
          ger.event(ns,'p3','view','d'),
        ])
        .then(-> ger.recommendations_for_person(ns, 'p1', {actions: {view:1, buy:1}}))
        .then((recommendations) ->

          recommendations.neighbourhood['p2'].should.exist
        )

  describe 'thing_neighbourhood', ->
    it 'should list things of people who actioned a thing', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','v','a', expires_at: tomorrow),
          ger.event(ns,'p1','v','b', expires_at: tomorrow),
        ])
        .then(-> ger.thing_neighbourhood(ns, 'a', {'v': 1}))
        .then((neighbourhood) ->
          neighbourhood.length.should.equal 1
          neighbourhood.map( (x) -> x.thing).should.include 'b'
        )

    it 'should not list things twice', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','v','a', expires_at: tomorrow),
          ger.event(ns,'p1','b','b', expires_at: tomorrow),
          ger.event(ns,'p1','v','b', expires_at: tomorrow),
        ])
        .then(-> ger.thing_neighbourhood(ns, 'a', {'v': 1, 'b': 1}))
        .then((neighbourhood) ->
          neighbourhood.length.should.equal 1
          neighbourhood.map( (x) -> x.thing).should.include 'b'
        )

    it 'should list things which cannot be recommended', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','v','a', expires_at: tomorrow),
          ger.event(ns,'p1','v','b', expires_at: yesterday),
          ger.event(ns,'p1','v','c', expires_at: tomorrow)
        ])
        .then(-> ger.thing_neighbourhood(ns, 'a', {'v': 1}))
        .then((neighbourhood) ->
          neighbourhood.length.should.equal 1
          neighbourhood.map( (x) -> x.thing).should.include 'c'
        )


  describe 'person_neighbourhood', ->
    it 'should return a list of similar people', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','action1','a', expires_at: tomorrow),
          ger.event(ns,'p2','action1','a', expires_at: tomorrow),
          ger.event(ns,'p3','action1','a', expires_at: tomorrow),

          ger.event(ns,'p1','action1','b', expires_at: tomorrow),
          ger.event(ns,'p3','action1','b', expires_at: tomorrow),

          ger.event(ns,'p4','action1','d', expires_at: tomorrow)
        ])
        .then(-> ger.person_neighbourhood(ns, 'p1', {'action1': 1}))
        .then((similar_people) ->
          similar_people.should.include 'p2'
          similar_people.should.include 'p3'
        )

    it 'should handle a non associated person', ->
      init_ger(ESM)
      .then (ger) ->
        bb.all([
          ger.event(ns,'p1','action1','not', expires_at: tomorrow)
          ger.event(ns,'p1','action1','a', expires_at: tomorrow),
          ger.event(ns,'p2','action1','a', expires_at: tomorrow),
          ger.event(ns,'p3','action1','a', expires_at: tomorrow),

          ger.event(ns,'p1','action1','b', expires_at: tomorrow),
          ger.event(ns,'p3','action1','b', expires_at: tomorrow),

          ger.event(ns,'p4','action1','d', expires_at: tomorrow)
        ])
        .then(-> ger.person_neighbourhood(ns, 'p1', {'action1': 1}))
        .then((similar_people) ->
          similar_people.length.should.equal 2
        )

module.exports = ger_tests;