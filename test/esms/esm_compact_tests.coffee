esm_tests = (ESM) ->
  describe 'ESM compacting database', ->
    describe '#compact_people', ->
      it 'should truncate the events of peoples history', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','view','t3')
          ])
          .then( -> 
            esm.pre_compact()
          )
          .then( ->
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 3
            esm.compact_people(2)
          )
          .then( -> 
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 2
          )


      it 'should truncate people by action', ->
        init_esm(ESM)
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
            esm.pre_compact()
          )
          .then( ->
            esm.compact_people(1)
          )
          .then( ->
            esm.post_compact()
          )
          .then( ->
            bb.all([esm.count_events(), esm.find_events('p1','view','t1'), esm.find_events('p1','buy','t1')])
          )
          .spread( (count, es1, es2) ->
            count.should.equal 2
            es1.length.should.equal 1
            es2.length.should.equal 1
          )

      it 'should have no duplicate events after', ->
        init_ger(ESM)
        .then (ger) ->
          rs = new Readable();
          rs.push('person,action,thing,2014-01-01,\n');
          rs.push('person,action,thing,2014-01-01,\n');
          rs.push(null);

          ger.bootstrap(rs)
          .then( ->
            ger.compact_database()
          )
          .then( ->
            ger.count_events()
          )
          .then( (count) ->
            count.should.equal 1
          )

    describe '#compact_things', ->
      it 'should truncate the events of things history', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p2','view','t1')
            esm.add_event('p3','view','t1')
          ])
          .then( -> 
            esm.pre_compact()
          )
          .then( ->
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 3
            esm.compact_things(2)
          )
          .then( -> 
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 2
          )

    describe '#expire_events', ->
      it 'should remove events that have expired', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event('p','a','t', {expires_at: new Date(0).toISOString()} )
          .then( ->
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 1
            esm.expire_events()
          )
          .then( -> esm.count_events())
          .then( (count) -> count.should.equal 0 )

    it "does not remove events that have no expiry date or future date", ->
      init_esm(ESM)
      .then (esm) ->
        bb.all([esm.add_event('p1','a','t'),  esm.add_event('p2','a','t', {expires_at:new Date(2050,10,10)}), esm.add_event('p3','a','t', {expires_at: new Date(0).toISOString()})])
        .then( ->
          esm.count_events()
        )
        .then( (count) ->
          count.should.equal 3
          esm.expire_events()
        )
        .then( -> esm.count_events())
        .then( (count) ->
          count.should.equal 2
          esm.find_events('p2','a','t')
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



