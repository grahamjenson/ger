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
            bb.all([esm.count_events(ns), esm.find_events(ns, person: 'p1', action: 'view', thing: 't1'), esm.find_events(ns, person: 'p1', action: 'buy', thing: 't1')])
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
          rs.push('person,action,thing,2012-02-02,\n');
          rs.push('person,action,thing,2013-02-02,\n');
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
            ger.find_events(ns, person: 'person', action: 'action', thing: 'thing')
          )
          .then( (events) ->
            events[0].created_at.getFullYear().should.equal 2013
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
            ger.find_events(ns, person: 'person', action: 'action', thing: 'thing')
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

      it 'should truncate things by action', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([

            esm.add_event(ns, 'p1','view','t1', created_at: new Date(4000))
            esm.add_event(ns, 'p1','view','t1', created_at: new Date(3000))
            esm.add_event(ns, 'p1','buy','t1', created_at: new Date(1000))

            esm.add_event(ns, 'p1','view','t1', created_at: new Date(5000))
            esm.add_event(ns, 'p1','buy','t1', created_at: new Date(6000))
          ])
          .then( ->
            esm.pre_compact(ns)
          )
          .then( ->
            esm.compact_things(ns, 1, ['view', 'buy'])
          )
          .then( ->
            esm.post_compact(ns)
          )
          .then( ->
            bb.all([esm.count_events(ns), esm.find_events(ns, action: 'view', thing: 't1'), esm.find_events(ns,  action: 'buy', thing: 't1')])
          )
          .spread( (count, es1, es2) ->
            count.should.equal 2
            es1.length.should.equal 1
            es2.length.should.equal 1
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



