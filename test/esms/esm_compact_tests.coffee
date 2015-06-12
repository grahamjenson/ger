esm_tests = (ESM) ->
  ns = "default"

  describe 'ESM compacting database', ->
    describe '#compact_people', ->
      it 'should truncate the events of peoples history', ->
        init_esm(ESM,ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','t1')
            esm.add_event(ns, 'p1','view','t2')
            esm.add_event(ns, 'p1','view','t3')
          ])
          .then( -> 
            esm.pre_compact(ns)
          )
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 3
            esm.compact_people(ns, 2, ['view'])
          )
          .then( -> 
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 2
          )


      it 'should truncate people by action', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([

            esm.add_event(ns, 'p1','view','t2', created_at: new Date(4000))
            esm.add_event(ns, 'p1','view','t3', created_at: new Date(3000))
            esm.add_event(ns, 'p1','buy','t3', created_at: new Date(1000))

            esm.add_event(ns, 'p1','view','t1', created_at: new Date(5000))
            esm.add_event(ns, 'p1','buy','t1', created_at: new Date(6000))
          ])
          .then( ->
            esm.pre_compact(ns)
          )
          .then( ->
            esm.compact_people(ns, 1, ['view', 'buy'])
          )
          .then( ->
            esm.post_compact(ns)
          )
          .then( ->
            bb.all([esm.count_events(ns), esm.find_events(ns, 'p1','view','t1'), esm.find_events(ns, 'p1','buy','t1')])
          )
          .spread( (count, es1, es2) ->
            count.should.equal 2
            es1.length.should.equal 1
            es2.length.should.equal 1
          )

      it 'should have no duplicate events after and take the latest creation', ->
        init_ger(ESM, ns)
        .then (ger) ->
          rs = new Readable();
          rs.push('person,action,thing,2015-02-02,\n');
          rs.push('person,action,thing,2020-02-02,\n');
          rs.push(null);

          ger.bootstrap(ns, rs)
          .then( ->
            ger.compact_database(ns, actions: ['action'])
          )
          .then( ->
            ger.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            ger.find_events(ns, 'person', 'action', 'thing')
          )
          .then( (events) ->
            events[0].created_at.getFullYear().should.equal 2020
          )

      it 'should have no duplicate expires_at events after and take the latest expiry', ->
        init_ger(ESM, ns)
        .then (ger) ->
          rs = new Readable();
          rs.push('person,action,thing,2014-01-01,2100-02-02\n');
          rs.push('person,action,thing,2014-01-01,2105-02-02\n');
          rs.push(null);

          ger.bootstrap(ns, rs)
          .then( ->
            ger.compact_database(ns, actions: ['action'])
          )
          .then( ->
            ger.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            ger.find_events(ns, 'person', 'action', 'thing')
          )
          .then( (events) ->
            events[0].expires_at.getFullYear().should.equal 2105
          )


    describe '#compact_things', ->
      it 'should truncate the events of things history', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','t1')
            esm.add_event(ns, 'p2','view','t1')
            esm.add_event(ns, 'p3','view','t1')
          ])
          .then( -> 
            esm.pre_compact(ns)
          )
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 3
            esm.compact_things(ns, 2, ['view'])
          )
          .then( -> 
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 2
          )

    describe '#expire_events', ->
      it 'should remove events that have expired', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event(ns, 'p','a','t', {expires_at: new Date(0).toISOString()} )
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            esm.expire_events(ns)
          )
          .then( -> esm.count_events(ns))
          .then( (count) -> count.should.equal 0 )

      it 'should be able to choose from what time to remove events', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event(ns, 'p','a','t', {expires_at: new Date(2050,10,10)} )
          .then(->
            esm.expire_events(ns).then( -> esm.count_events(ns) )
          )
          .then( (count) -> count.should.equal 1 )
          .then(->
            esm.expire_events(ns, new Date(2051,10,10)).then( -> esm.count_events(ns) )
          )
          .then( (count) -> count.should.equal 0 )

    it "does not remove events that have no expiry date or future date", ->
      init_esm(ESM)
      .then (esm) ->
        bb.all([esm.add_event(ns, 'p1','a','t'),  esm.add_event(ns, 'p2','a','t', {expires_at:new Date(2050,10,10)}), esm.add_event(ns, 'p3','a','t', {expires_at: new Date(0).toISOString()})])
        .then( ->
          esm.count_events(ns)
        )
        .then( (count) ->
          count.should.equal 3
          esm.expire_events(ns)
        )
        .then( -> esm.count_events(ns))
        .then( (count) ->
          count.should.equal 2
          esm.find_events(ns, 'p2','a','t')
        )
        .then( (events) ->
          event = events[0]
          event.expires_at.getTime().should.equal (new Date(2050,10,10)).getTime()
        )

    
    describe '#pre_compact', ->
      it 'should prepare the ESM for compaction'

    describe '#post_compact', ->
      it 'should perform tasks after compaction'


for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)



