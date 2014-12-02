describe "action cache", ->
  it 'should cache the action and invalidate when action changes', ->
    init_esm()
    .then (esm) ->
      esm.set_action_weight('view', 1)
      .then( ->
        (esm.action_cache == null).should.equal true
        esm.get_actions()
      )
      .then( (actions) ->
        esm.action_cache.should.equal actions
        actions[0].key.should.equal 'view'
        actions[0].weight.should.equal 1
      )
      .then( ->
        esm.get_actions()
      )
      .then( (actions) ->
        esm.action_cache.should.equal actions
        esm.set_action_weight('view', 2)
      )
      .then( (exists) ->
        (esm.action_cache == null).should.equal true
      )

describe "person_thing_history_count", ->
  it "return number of events for person", ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','view','t1')
        esm.add_event('p1','buy','t1')
        esm.add_event('p1','view','t2')
      ]) 
      .then( ->
        esm.person_thing_history_count('p1')
      )
      .then( (count) ->
        count.should.equal 2
        esm.person_thing_history_count('p2')
      )
      .then( (count) ->
        count.should.equal 0
      ) 

describe "estimate_event_count", ->
  it "should estimate the number of events", ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','view','t1')
        esm.add_event('p1','view','t2')
        esm.add_event('p1','view','t3')
      ]) 
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.estimate_event_count()
      )
      .then( (count) ->
        count.should.equal 3
      )

describe "filter_things_by_previous_actions", ->
  it 'should filter things a person has done before', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
      ]) 
      .then( ->
        esm.filter_things_by_previous_actions('p1', ['t1','t2'], ['view'])
      )
      .then( (things) ->
        things.length.should.equal 1
        things[0].should.equal 't2'
      )

  it 'should filter things only for given actions', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p1','buy','t2')
      ]) 
      .then( ->
        esm.filter_things_by_previous_actions('p1', ['t1','t2'], ['view'])
      )
      .then( (things) ->
        things.length.should.equal 1
        things[0].should.equal 't2'
      )     

describe "related_people", ->
  it 'should order by persons activity DATE (NOT DATETIME) then by COUNT', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)

        esm.add_event('p1','view','t1', {created_at: new Date(2014, 6, 6, 13, 1)})
        esm.add_event('p1','view','t4', {created_at: new Date(2014, 6, 6, 13, 1)})
        esm.add_event('p1','view','t2', {created_at: new Date(2014, 6, 6, 13, 30)})

        #t3 is more important as it has more recently been seen
        esm.add_event('p1','view','t3', {created_at: new Date(2014, 6, 7, 13, 0)})

        #Most recent person ordered first
        esm.add_event('p4','view','t3')
        esm.add_event('p4','buy','t1')

        #ordered second as most similar person
        esm.add_event('p2','view','t1')
        esm.add_event('p2','buy','t1')
        esm.add_event('p2','view','t4')

        #ordered third equal as third most similar people
        esm.add_event('p3','view','t2')
        esm.add_event('p3','buy','t2')
      ]) 
      .then( ->
        esm.get_related_people('p1', ['view', 'buy'], 'buy')
      )
      .then( (people) ->
        people[0].should.equal 'p4'
        people[1].should.equal 'p2'
        people[2].should.equal 'p3'
        people.length.should.equal 3
      )

  it 'should return similar people', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p2','view','t1')
        esm.add_event('p2','buy','t1')
      ]) 
      .then( ->
        esm.get_related_people('p1', ['view', 'buy'], 'buy')
      )
      .then( (people) ->
        people.length.should.equal 1
      )

  it 'should not return people that have not actioned action', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p2','view','t1')
      ]) 
      .then( ->
        esm.get_related_people('p1', ['view','buy'], 'buy')
      )
      .then( (people) ->
        people.length.should.equal 0
      )

 it 'should not return the given person', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.add_event('p1','view','t1')
      ]) 
      .then( ->
        esm.get_related_people('p1', ['view'], 'view')
      )
      .then( (people) ->
        people.length.should.equal 0
      )

  it 'should only return people related via given actions', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p2','view','t1')
        esm.add_event('p2','buy','t1')
      ]) 
      .then( ->
        esm.get_related_people('p1', ['buy'], 'buy')
      )
      .then( (people) ->
        people.length.should.equal 0
      )

describe "find_event", ->
  it "should return null if no event matches", ->
    init_esm()
    .then (esm) ->
      esm.find_event('p','a','t')
      .then( (event) ->
        true.should.equal event == null
      )

  it "should return an event if one matches", ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.find_event('p','a','t')
      )
      .then( (event) ->
        event.person.should.equal 'p' 
        event.action.should.equal 'a'
        event.thing.should.equal 't'
      )


describe "expires at", ->
  it 'should accept an expiry date', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('a', 1)
        esm.add_event('p','a','t', new Date().toISOString())
      ])
      .then( ->
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_action('a')
      )
      .then( (has_action) ->
        has_action.should.equal true
      )

bootstream = ->
  rs = new Readable();
  rs.push('person,action,thing,2014-01-01,\n');
  rs.push('person,action,thing1,2014-01-01,\n');
  rs.push('person,action,thing2,2014-01-01,\n');
  rs.push(null);
  rs

describe "#bootstrap", ->

  it 'should not exhaust the pg connections'

  it 'should load a set cof events from a file into the database', -> 
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push('person,action,thing1,2014-01-01,\n');
      rs.push('person,action,thing2,2014-01-01,\n');
      rs.push(null);

      esm.bootstrap(rs)
      .then( (returned_count) -> bb.all([returned_count, esm.count_events()]))
      .spread( (returned_count, count) -> 
        count.should.equal 3
        returned_count.should.equal 3
      )

    
  it 'should load a set of events from a file into the database', ->
    init_esm()
    .then (esm) ->
      fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
      esm.bootstrap(fileStream)
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 3)

describe "Schemas for multitenancy", ->
  it "should have different counts for different schemas", ->
    psql_esm1 = new PsqlESM(knex, "schema1")
    psql_esm2 = new PsqlESM(knex, "schema2")

    bb.all([psql_esm1.drop_tables(),psql_esm2.drop_tables()])
    .then( -> bb.all([psql_esm1.init_tables(),psql_esm2.init_tables()]) )
    .then( ->
      bb.all([
        psql_esm1.add_event('p','a','t')
        psql_esm1.add_event('p1','a','t')

        psql_esm2.add_event('p2','a','t')
      ])
    )
    .then( ->
      bb.all([psql_esm1.count_events(), psql_esm2.count_events() ]) 
    )
    .spread((c1,c2) ->
      c1.should.equal 2
      c2.should.equal 1
    )

describe '#initial tables', ->
  it 'should have empty actions table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('actions')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 0
      )

  it 'should have empty events table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('events')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 0
      )

describe '#add_event', ->

  it 'should add the event to the events table', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_event('p','a', 't')
      )
      .then( (has_event) ->
        has_event.should.equal true
      )

describe 'set_action_weight', ->
  it 'should not overwrite if set to false', ->
    init_esm()
    .then (esm) ->
      esm.set_action_weight('a', 1)
      .then( ->
        esm.get_action_weight('a')
      )
      .then( (weight) ->
        weight.should.equal 1
        esm.set_action_weight('a', 10, false).then( -> esm.get_action_weight('a'))
      )
      .then( (weight) ->
        weight.should.equal 1
      )


describe '#get_actions', ->
  it 'should return actions with weights', ->
    init_esm()
    .then (esm) ->
      bb.all([ esm.set_action_weight('a2',1) , esm.add_event('p','a','t'), esm.add_event('p','a2','t')])
      .then( -> esm.set_action_weight('a',10))
      .then( -> esm.get_actions())
      .then( (action_weights) ->
        action_weights[0].key.should.equal 'a'
        action_weights[0].weight.should.equal 10
        action_weights[1].key.should.equal 'a2'
        action_weights[1].weight.should.equal 1
      ) 



describe '#get_jaccard_distances_between_people', ->
  it 'should take a since, return recent as well', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','a','t1'),
        esm.add_event('p1','a','t2'),
        esm.add_event('p2','a','t2'),
        esm.add_event('p2','a','t1', created_at: moment().subtract(5, 'days'))
      ])
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a'], 500, 2))
      .spread( (limit_distances, jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      ) 

  it 'should return an object of people to jaccard distance', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','a','t1'),
        esm.add_event('p1','a','t2'),
        esm.add_event('p2','a','t2')
      ])
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .spread( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )     

  it 'should not be effected by multiple events of the same type', ->
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('p1,a,t1,2013-01-01,\n');
      rs.push('p1,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push('p2,a,t2,2013-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( -> esm.get_jaccard_distances_between_people('p1',['p2'],['a']))
      .spread( (jaccards) ->
        jaccards['p2']['a'].should.equal 1/2
      )   

describe '#recently_actioned_things_by_people', ->
  it 'should return list of things that people have actioned', ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'),esm.add_event('p2','a','t1')])
      .then( -> esm.recently_actioned_things_by_people('a',['p1','p2']))
      .then( (people_things) ->
        people_things['p1'][0].thing.should.equal 't'
        people_things['p1'].length.should.equal 1
        people_things['p2'][0].thing.should.equal 't1'
        people_things['p2'].length.should.equal 1
      ) 

  it 'should return the same item for different people', ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'), esm.add_event('p2','a','t')])
      .then( -> esm.recently_actioned_things_by_people('a',['p1','p2']))
      .then( (people_things) ->
        people_things['p1'][0].thing.should.equal 't'
        people_things['p1'].length.should.equal 1
        people_things['p2'][0].thing.should.equal 't'
        people_things['p2'].length.should.equal 1
      ) 
