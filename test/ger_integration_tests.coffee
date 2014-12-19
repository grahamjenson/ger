describe '#event', ->
  it 'should upsert same events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','c'),
        ger.event('p1','buy','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 1
      )

describe '#count_events', ->
  it 'should return 2 for 2 events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','buy','c'),
        ger.event('p1','view','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 2
      )

describe 'recommendations_for_person', ->

  it 'should reccommend basic things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
      ])
      .then(-> ger.recommendations_for_person('p2', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights[0].thing.should.equal 'a'
        item_weights.length.should.equal 1
      )

  it 'should recommend things based on user history', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','buy','c'),
        ger.event('p2','buy','d'),

        ger.event('p3','view','a'),
        ger.event('p3','buy','c')
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        #p1 is similar to (p1 by 1), p2 by .5, and (p3 by .5)
        #p1 buys a (a is 1), p2 and p3 buys c (.5 + .5=1) and p2 buys d (.5)
        items = (i.thing for i in item_weights)
        (items[0] == 'a' or items[0] == 'c').should.equal true
        items[2].should.equal 'd'
      )

  it 'should take a person and reccommend some things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),

        ger.event('p1','view','a'),

        ger.event('p2','view','a'),
        ger.event('p2','view','c'),
        ger.event('p2','view','d'),

        ger.event('p3','view','a'),
        ger.event('p3','view','c')
      ])
      .then(-> ger.recommendations_for_person('p1', 'view'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights[0].thing.should.equal 'a'
        item_weights[1].thing.should.equal 'c'
        item_weights[2].thing.should.equal 'd'

      )

  it 'should filter previously actioned things based on filter events option', ->
    init_ger(default_esm, 'public', previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights.length.should.equal 0
      )

  it 'should filter actioned things from other people', ->
    init_ger(default_esm, 'public', previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p1','buy','b'),
        ger.event('p2','buy','b'),
        ger.event('p2','buy','c'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights.length.should.equal 1
        item_weights[0].thing.should.equal 'c'
      ) 

  it 'should filter previously actioned by someone else', ->
    init_ger(default_esm, 'public', previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p2','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights.length.should.equal 0
      )

  it 'should not filter non actioned things', ->
    init_ger(default_esm, 'public', previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),
        ger.event('p2','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights.length.should.equal 1
        item_weights[0].thing.should.equal 'a'
      )

  it 'should not break with weird names (SQL INJECTION)', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action("v'i\new"),
        ger.event("'p\n,1};","v'i\new","'a\n;"),
        ger.event("'p\n2};","v'i\new","'a\n;"),
      ])
      .then(-> ger.recommendations_for_person("'p\n,1};","v'i\new"))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights[0].thing.should.equal "'a\n;"
        item_weights.length.should.equal 1
      )

  it 'should return the last_actioned_at date it was actioned at', ->
    date1 = moment().subtract(50, 'mins').toDate()
    date2 = moment().subtract(1, 'days').toDate()
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),
        ger.event('p3','view','a'),
        ger.event('p2','view','b', created_at: date1),
        ger.event('p3','view','b', created_at: date2),
      ])
      .then(-> ger.recommendations_for_person("p1","view"))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights.length.should.equal 2

        item_weights[0].thing.should.equal "a"
        item_weights[1].thing.should.equal "b"
        (+item_weights[1].last_actioned_at.toString().replace(".","")).should.equal date1.getTime()
      )

  it 'should people that contributed to recommendation', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p2','buy','a'),
        ger.event('p2','view','a'),

        ger.event('p1','view','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy', {explain: true}))
      .then((recommendations) ->
        item_weights = recommendations.recommendations
        item_weights[0].thing.should.equal 'a'
        item_weights[0].people.should.include 'p2'
        item_weights[0].people.length.should.equal 1
      )

  it 'should return only similar people who contributed to recommendations', ->
    init_ger(default_esm, 'public', {recommendations_limit: 1})
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','view','a'),

        ger.event('p2','buy','a'),
        ger.event('p2','view','a'),

        ger.event('p3','buy','b'),
        ger.event('p3','view','a'),
        ger.event('p3','view','d'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy', {explain: true}))
      .then((recommendations) ->
        recommendations.recommendations.length.should.equal 1

        recommendations.similar_people['p2'].should.exist
        Object.keys(recommendations.similar_people).length.should.equal 1
      )

describe 'find_similar_people', ->
  it 'should return a list of similar people', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.find_similar_people('p1', 'action1', {'action1': 1}))
      .then((similar_people) ->
        similar_people.should.include 'p2'
        similar_people.should.include 'p3'
      )

  it 'should handle a non associated person', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','action1','not')
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.find_similar_people('p1', 'action1', {'action1': 1}))
      .then((similar_people) ->
        similar_people.length.should.equal 2
      )

describe 'calculate_similarities_from_person', ->

  it "should weight recent events more than past events", ->
    init_ger(default_esm, 'public', recent_event_days: 1)
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.event('p1','view','a'),
        ger.event('p2','view','a', created_at: moment().subtract(50, 'mins')),
        ger.event('p3','view','a', created_at: moment().subtract(2, 'days')),
      ])
      .then(-> ger.calculate_similarities_from_person('p1', ['p2','p3'], {'view': 1}))
      .then((similar_people) ->
        similar_people.people_weights['p1'].should.equal 1
        similar_people.people_weights['p2'].should.equal 1
        similar_people.people_weights['p3'].should.equal .2
      )

  it 'should weight actions', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),
        ger.event('p3','view','a'),

        ger.event('p1','buy','b'),
        ger.event('p3','buy','b'),

        ger.event('p2','buy','x')
      ])
      .then(-> ger.calculate_similarities_from_person('p1', ['p2','p3'], {'view': .01, 'buy': .99}))
      .then((similar_people) ->
        similar_people.people_weights['p3'].should.equal 1
        similar_people.people_weights['p1'].should.equal 1
        similar_people.people_weights['p2'].should.equal 0.01
      )


  it 'should weight a list of similar people', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.calculate_similarities_from_person('p1', ['p2','p3'], {'action1': 1}))
      .then((similar_people) ->
        similar_people.people_weights['p1'].should.equal 1
        similar_people.people_weights['p3'].should.equal 1
        similar_people.people_weights['p2'].should.equal 1/2
        Object.keys(similar_people.people_weights).length.should.equal 3
      )

  it 'should handle a non associated event on person', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','not')
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b')
      ])
      .then(-> ger.calculate_similarities_from_person('p1', ['p2','p3'], {'action1': 1}))
      .then((similar_people) ->
        people_weights = similar_people.people_weights
        compare_floats( people_weights['p3'], 2/3).should.equal true
        compare_floats( people_weights['p2'] ,1/3).should.equal true
        Object.keys(people_weights).length.should.equal 3
      )


describe 'setting action weights', ->

  it 'should work getting all weights', ->
    init_ger()
    .then (ger) ->
      ger.action('buybuy', 10)
      .then( (val) -> ger.action('viewview', 1))
      .then( ->
        bb.all([
          ger.event('p1', 'buybuy', 'a'),
          ger.event('p1', 'buybuy', 'b'),
          ger.event('p1', 'buybuy', 'c'),
          ])
      )
      .then(-> ger.esm.get_actions())
      .then((actions) ->
        actions[0].key.should.equal "buybuy"
        actions[0].weight.should.equal 10
        actions[1].key.should.equal "viewview"
        actions[1].weight.should.equal 1
      )

  it 'should work multiple at the time', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('viewview', 1),
        ger.action('buybuy', 10),
      ])
      .then(-> ger.event('p1', 'buybuy', 'a'))
      .then(-> ger.get_action('buybuy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should override existing weight', ->
    init_ger()
    .then (ger) ->
      ger.event('p1', 'buy', 'a')
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should add the action with a weight to a sorted set', ->
    init_ger()
    .then (ger) ->
      ger.action('buy', 10)
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should default the action weight to 1', ->
    init_ger()
    .then (ger) ->
      ger.action('buy')
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 1)
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)
