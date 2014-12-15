describe 'crowd_weight', ->
  it 'should default do nothing', ->
    init_ger(default_esm, 'public')
    .then (ger) ->
      bb.all([
        ger.action('view',1),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','buy','x'),

        ger.event('p3','view','a'),
        ger.event('p3','view','b')
        ger.event('p3','buy','y'),

        ger.event('p4','view','a'),
        ger.event('p4','view','b')
        ger.event('p4','view','c')
        ger.event('p4','buy','y'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        recs = recs.recommendations
        recs[0].thing.should.equal 'x'
        recs[1].thing.should.equal 'y'
      )

  it 'should encourage recommendations with more people recommending it', ->
    init_ger(default_esm, 'public', crowd_weight: 1)
    .then (ger) ->
      bb.all([
        ger.action('view',1),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','buy','x'),

        ger.event('p3','view','a'),
        ger.event('p3','view','b')
        ger.event('p3','buy','y'),

        ger.event('p4','view','a'),
        ger.event('p4','view','b')
        ger.event('p4','view','c')
        ger.event('p4','buy','y'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        recs = recs.recommendations
        recs[0].thing.should.equal 'y'
        recs[1].thing.should.equal 'x'
      )

describe "minimum_history_limit", ->
  it "should not generate recommendations for events ", ->
    init_ger(default_esm, 'public', minimum_history_limit: 2)
    .then (ger) ->
      bb.all([
        ger.action('view',1),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),
        ger.event('p2','view','b'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'view'))
      .then((recs) ->
        recs.recommendations.length.should.equal 0
        ger.recommendations_for_person('p2', 'view')
      ).then((recs) ->
        recs.recommendations.length.should.equal 2
      )


describe "joining multiple gers", ->
  it "similar recommendations should return same confidence", ->
    bb.all([
      init_ger(default_esm, 'p1', {similar_people_limit: 2, person_history_limit: 4}, 'ger_1'),
      init_ger(default_esm, 'p2', {similar_people_limit: 4, person_history_limit: 8}, 'ger_2')
    ])
    .spread (ger1, ger2) ->
      bb.all([
        ger1.action('view', 1),
        ger2.action('view', 1),

        ger1.event('p1','view','a'),
        ger1.event('p2','view','a'),
        ger1.event('p2','buy','b'),

        ger2.event('p1','view','a'),
        ger2.event('p2','view','a'),
        ger2.event('p2','buy','b'),
      ])
      .then( -> bb.all([
          ger1.recommendations_for_person('p1', 'buy'),
          ger2.recommendations_for_person('p1', 'buy')
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
        ger.action('action1',1),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'action1'))
      .then((similar_people) ->
        similar_people.confidence.should.exist
      )

  it 'should return a confidence of 0 not NaN', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1',1),
        ger.event('p1','action1','a')
      ])
      .then(-> ger.recommendations_for_person('p1', 'action1'))
      .then((similar_people) ->
        similar_people.confidence.should.equal 0
      )

  it "higher weighted recommendations should return greater confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
        ger.event('p1','view','b'),
        ger.event('p2','view','a'),
        ger.event('p2','view','b'),
        ger.event('p2','view','c'),

        ger.event('p3','view','x'),
        ger.event('p3','view','y'),
        ger.event('p4','view','x'),
        ger.event('p4','view','z'),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person('p1', 'view')
          ger.recommendations_for_person('p3', 'view')
        ])
      )
      .spread((recs1, recs2) ->
        recs1.confidence.should.greaterThan recs2.confidence
      )

  it "more similar people should return greater confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),

        ger.event('p3','view','b'),
        ger.event('p4','view','b'),
        ger.event('p5','view','b'),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person('p1', 'view')
          ger.recommendations_for_person('p3', 'view')
        ])
      )
      .spread((recs1, recs2) ->

        recs2.confidence.should.greaterThan recs1.confidence
      )

  it "longer history should mean more confidence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),

        ger.event('p3','view','x'),
        ger.event('p3','view','b'),
        ger.event('p4','view','x'),
        ger.event('p4','view','b'),
      ])
      .then(->
        bb.all([
          ger.recommendations_for_person('p1', 'view')
          ger.recommendations_for_person('p3', 'view')
        ])
      )
      .spread((recs1, recs2) ->

        recs2.confidence.should.greaterThan recs1.confidence
      )

  it "should not return NaN as conifdence", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        recs.confidence.should.equal 0
      )

describe "weights", ->
  it "weights should determine the order of the recommendations", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.action('buy', 5),
        ger.event('p1','view','a'),
        ger.event('p1','buy','b'),

        ger.event('p6','buy','b'),
        ger.event('p6','buy','x'),

        ger.event('p2','view','a'),
        ger.event('p3','view','a'),
        ger.event('p4','view','a'),
        ger.event('p5','view','a')

        ger.event('p2','buy','y'),
        ger.event('p3','buy','y'),
        ger.event('p4','buy','y'),
        ger.event('p5','buy','y')
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        item_weights = recs.recommendations
        #p1 is similar by 1 view to p2 p3 p4 p5
        #p1 is similar to p6 by 1 buy
        #because a buy is worth 5 views x should be recommended before y
        item_weights[0].thing.should.equal 'b'
        item_weights[1].thing.should.equal 'y'
        item_weights[2].thing.should.equal 'x'
        ger.action('buy', 10)
      )
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights[0].thing.should.equal 'b'
        item_weights[1].thing.should.equal 'x'
        item_weights[2].thing.should.equal 'y'
      )

  it 'should not use actions with 0 or negative weights', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.action('neg_action', 0),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p2','buy','x'),

        ger.event('p1','neg_action','a'),
        ger.event('p3','neg_action','a'),
        ger.event('p3','buy','y'),

      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        item_weights = recs.recommendations
        item_weights.length.should.equal 1
        item_weights[0].thing.should.equal 'x'
      )

describe "person exploits,", ->
  it 'related_things_limit should stop one persons recommendations eliminating the other recommendations', ->
    init_ger(default_esm, 'public', related_things_limit: 1)
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.action('buy', 5),
        ger.event('p1','view','a'),
        ger.event('p1','view','b'),
        #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
        ger.event('p2','view','a'),
        ger.event('p2','view','b'),
        ger.event('p2','buy','x', created_at: moment().subtract(2, 'days')),

        ger.event('p3','view','a'),
        ger.event('p3','buy','l', created_at: moment().subtract(3, 'hours')),
        ger.event('p3','buy','m', created_at: moment().subtract(2, 'hours')),
        ger.event('p3','buy','n', created_at: moment().subtract(1, 'hours'))
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
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
        rs.push("bad_person,view,t1,#{new Date().toISOString()},\n");
        rs.push("bad_person,buy,t1,#{new Date().toISOString()},\n");
      rs.push(null);
      ger.bootstrap(rs)
      .then( ->
        bb.all([
          ger.action('buy'),
          ger.action('view'),
          ger.event('real_person', 'view', 't2')
          ger.event('real_person', 'buy', 't2')
          ger.event('person', 'view', 't1')
          ger.event('person', 'view', 't2')
        ])
      )
      .then( ->
        ger.recommendations_for_person('person', 'buy')
      )
      .then((recs) ->
        item_weights = recs.recommendations
        temp = {}
        (temp[tw.thing] = tw.weight for tw in item_weights)
        temp['t1'].should.equal temp['t2']
      )

