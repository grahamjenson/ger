esm_tests = (ESM) ->
  describe 'construction', ->

    describe '#initialize #exists #destroy', ->
      it 'should initialize namespace', ->
        esm = new ESM("namespace", {knex: knex, r: r})
        esm.destroy()
        .then( -> esm.exists())
        .then( (exist) -> exist.should.equal false)
        .then( -> esm.initialize())
        .then( -> esm.exists())
        .then( (exist) -> exist.should.equal true)    

      it 'should start with no actions or events', ->
        esm = new ESM("namespace", {knex: knex, r: r})
        esm.destroy()
        .then( -> esm.initialize())
        .then( -> bb.all([esm.count_events(), esm.get_actions()]))
        .spread( (count, actions) -> 
          count.should.equal 0
          actions.length.should.equal 0
        )
        
      it 'should not error out or remove events if re-initialized', ->
        esm = new ESM("namespace", {knex: knex, r: r})
        esm.destroy()
        .then( -> esm.initialize())
        .then( -> esm.add_event('p','a','t'))
        .then( -> esm.count_events())
        .then( (count) -> count.should.equal 1)
        .then( -> esm.initialize())
        .then( -> esm.count_events())
        .then( (count) -> count.should.equal 1)

      it 'should create resources for ESM namespace', ->
        esm1 = new ESM("namespace1", {knex: knex, r: r}) #pass knex as it might be needed
        esm2 = new ESM("namespace2", {knex: knex, r: r}) #pass knex as it might be needed
        bb.all([esm1.destroy(), esm2.destroy()])
        .then( -> bb.all([esm1.initialize(), esm2.initialize()]) )
        .then( ->
          bb.all([
            esm1.add_event('p','a','t')
            esm1.add_event('p1','a','t')
            
            esm2.add_event('p2','a','t')
          ])
        )
        .then( ->
          bb.all([esm1.count_events(), esm2.count_events() ])
        )
        .spread((c1,c2) ->
          c1.should.equal 2
          c2.should.equal 1
        )

      it 'should destroy should not break if resource does not exist', ->
        esm = new ESM("namespace", {knex: knex, r: r})
        esm.destroy()
        .then( -> esm.destroy())

  describe 'recommendation methods', ->
    describe '#get_actions', ->
      it 'should returns all the assigned actions with weights in descending order', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('a2',1),
            esm.set_action_weight('a',10)
          ])
          .then( -> esm.get_actions())
          .then( (action_weights) ->
            action_weights[0].key.should.equal 'a'
            action_weights[0].weight.should.equal 10
            action_weights[1].key.should.equal 'a2'
            action_weights[1].weight.should.equal 1
          )

    describe '#find_similar_people' , ->
      it 'should return a list of similar people', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.set_action_weight('buy', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p2','view','t1')
            esm.add_event('p2','buy','t1')
            esm.add_event('p1','buy','t1')
          ])
          .then( ->
            esm.find_similar_people('p1', ['view', 'buy'], 'buy')
          )
          .then( (people) ->
            people.length.should.equal 1
          )

      it 'should not return people that have not actioned action', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.set_action_weight('buy', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p2','view','t1')
          ])
          .then( ->
            esm.find_similar_people('p1', ['view','buy'], 'buy')
          )
          .then( (people) ->
            people.length.should.equal 0
          )

     it 'should not return the given person', ->
        @timeout(360000)
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.add_event('p1','view','t1')
          ])
          .then( ->
            esm.find_similar_people('p1', ['view'], 'view')
          )
          .then( (people) ->
            people.length.should.equal 0
          )

      it 'should only return people related via given actions', ->
        @timeout(60000)
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.set_action_weight('buy', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p2','view','t1')
            esm.add_event('p2','buy','t1')
          ])
          .then( ->
            esm.find_similar_people('p1', ['buy'], 'buy')
          )
          .then( (people) ->
            people.length.should.equal 0
          )

    describe '#calculate_similarities_from_person', ->
      it 'more similar histories should be greater', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1')
            esm.add_event('p1','a','t2')

            esm.add_event('p2','a','t1')
            esm.add_event('p2','a','t2')

            esm.add_event('p3','a','t1')
            esm.add_event('p3','a','t3')
          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2','p3'],['a']))
          .then( (similarities) ->
            similarities['p3']['a'].should.be.lessThan(similarities['p2']['a'])
          )

      it 'should handle multiple actions', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1')
            esm.add_event('p1','b','t2')

            esm.add_event('p2','a','t1')
            esm.add_event('p2','b','t2')

            esm.add_event('p3','a','t1')
            esm.add_event('p3','b','t3')
          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2','p3'],['a','b']))
          .then( (similarities) ->
            similarities['p3']['b'].should.be.lessThan(similarities['p2']['b'])
            similarities['p3']['a'].should.be.equal(similarities['p2']['a'])
          )

      it 'should calculate the similarity between a person and a set of people for a list of actions', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1'),
            esm.add_event('p2','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.exist
          )

      it 'should have a higher similarity for more recent events of person', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1', created_at: new Date()),
            esm.add_event('p2','a','t1', created_at: moment().subtract(2, 'days').toDate())
            esm.add_event('p3','a','t1', created_at: moment().subtract(10, 'days').toDate())

          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2', 'p3'],['a'], 500, 5))
          .then( (similarities) ->
            similarities['p3']['a'].should.be.lessThan(similarities['p2']['a'])
          )

      it 'should have a same similarity if histories are inversed', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1', created_at: new Date()),
            esm.add_event('p2','a','t1', created_at: moment().subtract(10, 'days').toDate())

            esm.add_event('p1','a','t2', created_at: moment().subtract(10, 'days').toDate()),
            esm.add_event('p3','a','t2', created_at: new Date())
          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2', 'p3'],['a'], 500, 5))
          .then( (similarities) ->
            similarities['p3']['a'].should.equal similarities['p2']['a']
          )

      it 'should not be effected by having same events (through add_event)', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1'),
            esm.add_event('p2','a','t1')
            esm.add_event('p3','a','t1')
            esm.add_event('p3','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person('p1',['p2', 'p3'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.equal similarities['p3']['a']
          )

      it 'should not be effected by having same events (through bootstrap)', ->
        init_esm(ESM)
        .then (esm) ->
          rs = new Readable();
          rs.push('p1,a,t1,2013-01-01,\n');
          rs.push('p2,a,t1,2013-01-01,\n');
          rs.push('p3,a,t1,2013-01-01,\n');
          rs.push('p3,a,t1,2013-01-01,\n');
          rs.push(null);
          esm.bootstrap(rs)
          .then( -> esm.calculate_similarities_from_person('p1',['p2', 'p3'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.equal similarities['p3']['a']
          )

      it 'should not be effected by having bad names', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight("v'i\new", 1)
            esm.add_event("'p\n,1};","v'i\new","'a\n;"),
            esm.add_event("'p\n2};","v'i\new","'a\n;")
          ])
          .then(-> esm.calculate_similarities_from_person("'p\n,1};",["'p\n2};"], ["v'i\new"]))
          .then((similarities) ->
            similarities["'p\n2};"]["v'i\new"].should.be.greaterThan(0)
          )

    describe '#recently_actioned_things_by_people', ->
      it 'should return a list of things that people have actioned', ->
        init_esm(ESM)
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
        init_esm(ESM)
        .then (esm) ->
          bb.all([esm.add_event('p1','a','t'), esm.add_event('p2','a','t')])
          .then( -> esm.recently_actioned_things_by_people('a',['p1','p2']))
          .then( (people_things) ->
            people_things['p1'][0].thing.should.equal 't'
            people_things['p1'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't'
            people_things['p2'].length.should.equal 1
          )

      it 'should be limited by related things limit', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1'),
            esm.add_event('p1','a','t2'),
            esm.add_event('p2','a','t2')
          ])
          .then( -> esm.recently_actioned_things_by_people('a',['p1','p2'], 1))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
            people_things['p2'].length.should.equal 1
          )

    describe '#person_history_count', ->
      it 'should return the number of things a person has actioned in their history', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','buy','t1')
            esm.add_event('p1','view','t2')
          ])
          .then( ->
            esm.person_history_count('p1')
          )
          .then( (count) ->
            count.should.equal 2
            esm.person_history_count('p2')
          )
          .then( (count) ->
            count.should.equal 0
          )

    describe '#filter_things_by_previous_actions', ->
      it 'should remove things that a person has previously actioned', ->
        init_esm(ESM)
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
        init_esm(ESM)
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

      it 'should filter things for multiple actions', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.set_action_weight('view', 1)
            esm.set_action_weight('buy', 1)
            esm.add_event('p1','view','t1')
            esm.add_event('p1','buy','t2')
          ])
          .then( ->
            esm.filter_things_by_previous_actions('p1', ['t1','t2'], ['view', 'buy'])
          )
          .then( (things) ->
            things.length.should.equal 0
          )

  describe 'inserting data', ->
    describe '#add_event', ->
      it 'should add an event to the ESM', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event('p','a','t')
          .then( ->
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 1
            esm.find_events('p','a', 't')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
          )

    describe '#count_events', ->
      it 'should return the number of events in the event store', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event('p','a','t')
          .then( ->
            esm.count_events()
          )
          .then( (count) ->
            count.should.equal 1
          )

    describe '#estimate_event_count', ->
      it 'should be a fast estimate of events', ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','view','t3')
          ])
          .then( ->
            esm.pre_compact()
          )
          .then( ->
            esm.estimate_event_count()
          )
          .then( (count) ->
            count.should.equal 3
          )

    describe '#delete_events', ->
      it "should return 0 if no events are deleted", ->
        init_esm(ESM)
        .then (esm) ->
          esm.delete_events('p','a','t')
          .then( (ret) ->
            ret.deleted.should.equal 0
          )

      it "should delete events from esm", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','like','t1')
          ])
          .then( ->
            esm.delete_events('p1','view','t1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 1
            esm.count_events()
          ).then( (count) ->
            count.should.equal 2
          )

      it "should delete events from esm for person", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','like','t1')
          ])
          .then( ->
            esm.delete_events('p1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events()
          ).then( (count) ->
            count.should.equal 0
          )

      it "should delete events from esm for action", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','like','t1')
          ])
          .then( ->
            esm.delete_events(null, 'view')
          )
          .then( (ret) ->
            ret.deleted.should.equal 2
            esm.count_events()
          ).then( (count) ->
            count.should.equal 1
          )

      it "should delete all events if no value is given", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','like','t1')
          ])
          .then( ->
            esm.delete_events()
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events()
          ).then( (count) ->
            count.should.equal 0
          )

    describe '#find_events', ->
      it 'should return the event', ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event('p','a','t')
          .then( ->
            esm.find_events('p','a','t')
          )
          .then( (events) ->
            event = events[0]
            event.person.should.equal 'p'
            event.action.should.equal 'a'
            event.thing.should.equal 't'
          )

      it "should return null if no event matches", ->
        init_esm(ESM)
        .then (esm) ->
          esm.find_events('p','a','t')
          .then( (events) ->
            events.length.should.equal 0
          )

      it "should find event with only one argument", ->
        init_esm(ESM)
        .then (esm) ->
          esm.add_event('p','a','t')
          .then( ->
            bb.all([
              esm.find_events('p')
              esm.find_events(null, 'a')
              esm.find_events(null, undefined, 't')
            ])
          )
          .spread( (events1, events2, events3) ->
            e1 = events1[0]
            e2 = events2[0]
            e3 = events3[0]
            for event in [e1, e2, e3]
              event.person.should.equal 'p'
              event.action.should.equal 'a'
              event.thing.should.equal 't'
          )

      it "should return multiple events", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','view','t1')
            esm.add_event('p1','view','t2')
            esm.add_event('p1','like','t1')
          ])
          .then( ->
            bb.all([
              esm.find_events('p1')
              esm.find_events('p1', 'view')
              esm.find_events('p1', 'view', 't1')
              esm.find_events(null, 'view', null)
              esm.find_events('p1', null, 't1')
            ])
          )
          .spread( (events1, events2, events3, events4, events5) ->
            events1.length.should.equal 3
            events2.length.should.equal 2
            events3.length.should.equal 1
            events4.length.should.equal 2
            events5.length.should.equal 2
          )

      it "should return events in created_at descending order (most recent first)", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1', created_at: new Date()),
            esm.add_event('p1','a','t2', created_at: moment().subtract(2, 'days').toDate())
            esm.add_event('p1','a','t3', created_at: moment().subtract(10, 'days').toDate())
          ])
          .then( ->
            esm.find_events('p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            events[0].thing.should.equal 't1'
            events[1].thing.should.equal 't2'
            events[2].thing.should.equal 't3'
          )

      it "should limit the returned events to size", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1', created_at: new Date()),
            esm.add_event('p1','a','t2', created_at: moment().subtract(2, 'days').toDate())
            esm.add_event('p1','a','t3', created_at: moment().subtract(10, 'days').toDate())
          ])
          .then( ->
            esm.find_events('p1', null, null, {size: 2})
          )
          .then( (events) ->
            events.length.should.equal 2
            events[0].thing.should.equal 't1'
            events[1].thing.should.equal 't2'
          )

      it "should return pagable events", ->
        init_esm(ESM)
        .then (esm) ->
          bb.all([
            esm.add_event('p1','a','t1', created_at: new Date()),
            esm.add_event('p1','a','t2', created_at: moment().subtract(2, 'days').toDate())
            esm.add_event('p1','a','t3', created_at: moment().subtract(10, 'days').toDate())
          ])
          .then( ->
            esm.find_events('p1', null, null, {size: 2, page: 1})
          )
          .then( (events) ->
            events.length.should.equal 1
            events[0].thing.should.equal 't3'
          )

    describe '#set_action_weight #get_action_weight', ->
      it 'should assign an actions weight', ->
        init_esm(ESM)
        .then (esm) ->
          esm.set_action_weight('a', 2)
          .then( -> esm.get_action_weight('a'))
          .then( (weight) ->
            weight.should.equal 2
          )

      it 'should not overwrite if set to false', ->
        init_esm(ESM)
        .then (esm) ->
          esm.set_action_weight('a', 2)
          .then( -> esm.get_action_weight('a'))
          .then( (weight) ->
            weight.should.equal 2
            esm.set_action_weight('a', 10, false)
          )
          .then(-> esm.get_action_weight('a'))
          .then( (weight) ->
            weight.should.equal 2
          )

    describe '#bootstrap', ->
      it 'should add a stream of events (person,action,thing,created_at,expires_at)', ->
        init_esm(ESM)
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

      it 'should select the most recent created_at date for any duplicate events', ->
        init_esm(ESM)
        .then (esm) ->
          rs = new Readable();
          rs.push('person,action,thing,2013-01-01,\n');
          rs.push('person,action,thing,2014-01-01,\n');
          rs.push(null);
          esm.bootstrap(rs)
          .then( ->
            esm.pre_compact()
          )
          .then( ->
            esm.compact_people()
          )
          .then( -> esm.count_events())
          .then( (count) ->
            count.should.equal 1
            esm.find_events('person','action','thing')
          )
          .then( (events) ->
            event = events[0]
            expected_created_at = new Date('2014-01-01')
            event.created_at.getFullYear().should.equal expected_created_at.getFullYear()
          )

      it 'should load a set of events from a file into the database', ->
        init_esm(ESM)
        .then (esm) ->
          fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
          esm.bootstrap(fileStream)
          .then( (count) -> count.should.equal 3; esm.count_events())
          .then( (count) -> count.should.equal 3)


for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)



