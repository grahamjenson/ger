esm_tests = (ESM) ->
  describe 'construction', ->
    describe '#new', ->
      it 'should create new ESM'

    describe '#initialize', ->
      it 'should create resources for ESM namespace', ->
        esm1 = new ESM("schema1", {knex: knex}) #pass knex as it might be needed
        esm2 = new ESM("schema2", {knex: knex}) #pass knex as it might be needed

        bb.all([esm1.destroy(),esm2.destroy()])
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

    describe '#destroy', ->
      it 'should destroy resources for ESM namespace'

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
      it 'should calculate the distance between a person and a set of people for a list of actions'

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
      it 'should remove things that a person has previously actioned'


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
            esm.find_event('p','a', 't')
          )
          .then( (event) ->
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


    describe '#find_event', ->
      it 'should return the event', ->
        init_esm(ESM)
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

      it "should return null if no event matches", ->
        init_esm(ESM)
        .then (esm) ->
          esm.find_event('p','a','t')
          .then( (event) ->
            true.should.equal event == null
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

     
      it 'should load a set of events from a file into the database', ->
        init_esm(ESM)
        .then (esm) ->
          fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
          esm.bootstrap(fileStream)
          .then( -> esm.count_events())
          .then( (count) -> count.should.equal 3)

  describe 'ESM compacting database', ->
    describe '#pre_compact', ->
      it 'should prepare the ESM for compaction'

    describe '#compact_people', ->
      it 'should truncate the events of peoples history'

    describe '#compact_things', ->
      it 'should truncate the events of things history'

    describe '#expire_events', ->
      it 'should remove events that have expired'

    describe '#post_compact', ->
      it 'should perform tasks after compaction'


for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)

  
    