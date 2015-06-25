ns = global.default_namespace

describe 'recommending for a person', ->
  it 'should recommend similar things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','b', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1',  actions: {view: 1}, filter_previous_actions: ['view']))
      .then((recs) ->
        console.log recs
        recs = recs.recommendations
        recs.length.should.equal 1
        recs[0].thing.should.equal 'b'
      )

describe 'time_until_expiry', ->
  it 'should not return recommendations that will expire within time_until_expiry seconds', ->
    one_hour = 60*60
    one_day = 24*one_hour
    a1day = moment().add(1, 'days').format()
    a2days = moment().add(2, 'days').format()
    a3days = moment().add(3, 'days').format() 

    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a'),

        ger.event(ns, 'p2','view','a'),
        ger.event(ns, 'p2','buy','x', expires_at: a1day),
        ger.event(ns, 'p2','buy','y', expires_at: a2days),
        ger.event(ns, 'p2','buy','z', expires_at: a3days)
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', time_until_expiry: (one_day + one_hour), actions: {view: 1, buy: 1}))
      .then((recs) ->
        recs = recs.recommendations
        recs.length.should.equal 2
        sorted_recs = [recs[0].thing, recs[1].thing]
        sorted_recs[0].should.equal 'y'
        sorted_recs[1].should.equal 'z'
      )

describe "minimum_history_required", ->
  it "should not generate recommendations for events ", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','b', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', minimum_history_required: 2, actions: {view: 1}))
      .then((recs) ->
        recs.recommendations.length.should.equal 0
        ger.recommendations_for_person(ns, 'p2', minimum_history_required: 2, actions: {view: 1})
      ).then((recs) ->
        recs.recommendations.length.should.equal 2
      )


describe "joining multiple gers", ->
  it "similar recommendations should return same confidence", ->
    ns1 = 'ger_1'
    ns2 = 'ger_2'
    bb.all([
      init_ger(default_esm, ns1),
      init_ger(default_esm, ns2)
    ])
    .spread (ger1, ger2) ->
      bb.all([

        ger1.event(ns1, 'p1','view','a', expires_at: tomorrow),
        ger1.event(ns1, 'p2','view','a', expires_at: tomorrow),
        ger1.event(ns1, 'p2','buy','b', expires_at: tomorrow),

        ger2.event(ns2, 'p1','view','a', expires_at: tomorrow),
        ger2.event(ns2, 'p2','view','a', expires_at: tomorrow),
        ger2.event(ns2, 'p2','buy','b', expires_at: tomorrow),
      ])
      .then( -> bb.all([
          ger1.recommendations_for_person(ns1, 'p1', {neighbourhood_size: 2, history_search_size: 4, actions: {view: 1}}),
          ger2.recommendations_for_person(ns2, 'p1', {neighbourhood_size: 4, history_search_size: 8, actions: {view: 1}})
        ])
      )
      .spread((recs1, recs2) ->
        recs1.confidence.should.equal recs2.confidence
      )


describe "confidence", ->

  it 'should return a confidence ', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','action1','a', expires_at: tomorrow),
        ger.event(ns, 'p2','action1','a', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', 'action1', actions: {action1: 1}))
      .then((similar_people) ->
        similar_people.confidence.should.exist
      )

  it 'should return a confidence of 0 not NaN', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','action1','a', expires_at: tomorrow)
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', 'action1', actions: {action1: 1}))
      .then((similar_people) ->
        similar_people.confidence.should.equal 0
      )

  it "higher weighted recommendations should return greater confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','view','b', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','b', expires_at: tomorrow),
        ger.event(ns, 'p2','view','c', expires_at: tomorrow),

        ger.event(ns, 'p3','view','x', expires_at: tomorrow),
        ger.event(ns, 'p3','view','y', expires_at: tomorrow),
        ger.event(ns, 'p4','view','x', expires_at: tomorrow),
        ger.event(ns, 'p4','view','z', expires_at: tomorrow),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person(ns, 'p1', actions: {view: 1})
          ger.recommendations_for_person(ns, 'p3', actions: {view: 1})
        ])
      )
      .spread((recs1, recs2) ->
        recs1.confidence.should.greaterThan recs2.confidence
      )

  it "more similar people should return greater confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),

        ger.event(ns, 'p3','view','b', expires_at: tomorrow),
        ger.event(ns, 'p4','view','b', expires_at: tomorrow),
        ger.event(ns, 'p5','view','b', expires_at: tomorrow),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person(ns, 'p1', actions: {view: 1})
          ger.recommendations_for_person(ns, 'p3', actions: {view: 1})
        ])
      )
      .spread((recs1, recs2) ->

        recs2.confidence.should.greaterThan recs1.confidence
      )

  it "longer history should mean more confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','a', expires_at: tomorrow),

        ger.event(ns, 'p3','view','x', expires_at: tomorrow),
        ger.event(ns, 'p3','view','b', expires_at: tomorrow),
        ger.event(ns, 'p4','view','x', expires_at: tomorrow),
        ger.event(ns, 'p4','view','b', expires_at: tomorrow),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person(ns, 'p1', actions: {view: 1})
          ger.recommendations_for_person(ns, 'p3', actions: {view: 1})
        ])
      )
      .spread((recs1, recs2) ->

        recs2.confidence.should.greaterThan recs1.confidence
      )

  it "should not return NaN as conifdence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', actions: {view: 1}))
      .then((recs) ->
        recs.confidence.should.equal 0
      )

describe "weights", ->
  it "weights should determine the order of the recommendations", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a', expires_at: tomorrow),
        ger.event(ns, 'p1','buy','b', expires_at: tomorrow),

        ger.event(ns, 'p2','view','a', expires_at: tomorrow),
        ger.event(ns, 'p2','view','c', expires_at: tomorrow),

        ger.event(ns, 'p3','buy','b', expires_at: tomorrow),
        ger.event(ns, 'p3','buy','d', expires_at: tomorrow),
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', actions: {view: 1, buy: 1}, filter_previous_actions: ['buy', 'view'] ))
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights.length.should.equal 2
        item_weights[0].weight.should.equal item_weights[1].weight

        ger.recommendations_for_person(ns, 'p1', actions: {view: 1, buy: 2}, filter_previous_actions: ['buy', 'view'])
      )
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights[0].weight.should.be.greaterThan item_weights[1].weight
        item_weights[0].thing.should.equal 'd'
        item_weights[1].thing.should.equal 'c'
      )

  it 'should not use actions with 0 or negative weights', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','action1','a'),
        ger.event(ns, 'p2','action1','a'),
        ger.event(ns, 'p2','buy','x', expires_at: tomorrow),

        ger.event(ns, 'p1','neg_action','a'),
        ger.event(ns, 'p3','neg_action','a'),
        ger.event(ns, 'p3','buy','y', expires_at: tomorrow),

      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', actions: {action1: 1, neg_action: 0, buy: 1}))
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights.length.should.equal 1
        item_weights[0].thing.should.equal 'x'
      )

describe "person exploits,", ->
  it 'related_things_limit should stop one persons recommendations eliminating the other recommendations', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event(ns, 'p1','view','a'),
        ger.event(ns, 'p1','view','b'),
        #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
        ger.event(ns, 'p2','view','a'),
        ger.event(ns, 'p2','view','b'),
        ger.event(ns, 'p2','buy','x', created_at: moment().subtract(2, 'days').toDate(), expires_at: tomorrow),

        ger.event(ns, 'p3','view','a'),
        ger.event(ns, 'p3','buy','l', created_at: moment().subtract(3, 'hours').toDate(), expires_at: tomorrow),
        ger.event(ns, 'p3','buy','m', created_at: moment().subtract(2, 'hours').toDate(), expires_at: tomorrow),
        ger.event(ns, 'p3','buy','n', created_at: moment().subtract(1, 'hours').toDate(), expires_at: tomorrow)
      ])
      .then(-> ger.recommendations_for_person(ns, 'p1', related_things_limit: 1, actions: {buy: 5, view: 1}))
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights.length.should.equal 2
        item_weights[0].thing.should.equal 'x'
        item_weights[1].thing.should.equal 'n'
      )


  it "a single persons mass interaction should not outweigh 'real' interations", ->
    init_ger()
    .then (ger) ->
      rs = new Readable();
      for x in [1..100]
        rs.push("bad_person,view,t1,#{new Date().toISOString()},#{tomorrow.format()}\n");
        rs.push("bad_person,buy,t1,#{new Date().toISOString()},#{tomorrow.format()}\n");
      rs.push(null);
      ger.bootstrap(ns,rs)
      .then( ->
        bb.all([
          ger.event(ns, 'real_person', 'view', 't2', expires_at: tomorrow)
          ger.event(ns, 'real_person', 'buy', 't2', expires_at: tomorrow)
          ger.event(ns, 'person', 'view', 't1', expires_at: tomorrow)
          ger.event(ns, 'person', 'view', 't2', expires_at: tomorrow)
        ])
      )
      .then( ->
        ger.recommendations_for_person(ns, 'person', actions: {buy:1, view:1})
      )
      .then((recs) ->
        item_weights = recs.recommendations
        temp = {}
        (temp[tw.thing] = tw.weight for tw in item_weights)
        temp['t1'].should.equal temp['t2']
      )


