describe "get_active_people", ->
  it 'should return an ordered list of the most active people', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.add_event('p1','view','t1')
        esm.add_event('p1','view','t2')
        esm.add_event('p1','view','t3')

        esm.add_event('p2','view','t2')
        esm.add_event('p2','view','t3')
      ])
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.get_active_people()
      )
      .then( (people) ->
        people[0].should.equal 'p1'
        people[1].should.equal 'p2'
      )

describe "truncate_people_per_action", ->
  it 'should truncate people events to a smaller value', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.add_event('p1','view','t1')
        esm.add_event('p1','view','t2')
        esm.add_event('p1','view','t3')

        esm.add_event('p2','view','t2')
        esm.add_event('p2','view','t3')
      ]) 
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.truncate_people_per_action(['p1', 'p2'], 2)
      )
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 4
      )   

  it 'should truncate people by action then broadly', ->
    init_esm()
    .then (esm) ->
      bb.all([
        esm.set_action_weight('view', 1)
        esm.set_action_weight('buy', 10)
        
        esm.add_event('p1','view','t2', created_at: new Date(4000))
        esm.add_event('p1','view','t3', created_at: new Date(3000))
        esm.add_event('p1','buy','t3', created_at: new Date(1000))

        esm.add_event('p1','view','t1', created_at: new Date(5000))
        esm.add_event('p1','buy','t1', created_at: new Date(6000))
      ]) 
      .then( ->
        esm.vacuum_analyze()
      )
      .then( ->
        esm.truncate_people_per_action(['p1'], 1)
      )
      .then( ->
        bb.all([esm.count_events(), esm.find_event('p1','view','t1'), esm.find_event('p1','buy','t1')])
      )
      .spread( (count, e1, e2) ->
        count.should.equal 2
        (null != e1).should.be.true
        (null != e2).should.be.true
        
      ) 


describe "remove_events_till_size", ->
  it "removes old events till there is only number_of_events left", ->
    init_esm()
    .then (esm) ->    
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 4
        esm.remove_events_till_size(2)
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 2
      )


describe "remove_expired_events", ->
  it "removes the events passed their expiry date", ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t', {expires_at: new Date(0).toISOString()} )
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 1
        esm.remove_expired_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 0 )

  it "does not remove events that have no expiry date or future date", ->
    init_esm()
    .then (esm) ->
      bb.all([esm.add_event('p1','a','t'),  esm.add_event('p2','a','t', {expires_at:new Date(2050,10,10)}), esm.add_event('p3','a','t', {expires_at: new Date(0).toISOString()})])
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 3
        esm.remove_expired_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 2 
        esm.find_event('p2','a','t')
      )
      .then( (event) ->
        event.expires_at.getTime().should.equal (new Date(2050,10,10)).getTime() 
      )

describe "remove_non_unique_events", ->
  it "remove all events that are not unique", ->
    init_esm()
    .then (esm) ->
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 2
        esm.remove_non_unique_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> count.should.equal 1 )

  it "removes events that have a older created_at", ->
    init_esm()
    .then (esm) ->    
      rs = new Readable();
      rs.push('person,action,thing,2013-01-01,\n');
      rs.push('person,action,thing,2014-01-01,\n');
      rs.push(null);
      esm.bootstrap(rs)
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 2
        esm.remove_non_unique_events()
      )
      .then( -> esm.count_events())
      .then( (count) -> 
        count.should.equal 1
        esm.find_event('person','action','thing')
      )
      .then( (event) ->
        expected_created_at = new Date('2014-01-01')
        event.created_at.getFullYear().should.equal expected_created_at.getFullYear() 
      )
