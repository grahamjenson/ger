esm_tests = (ESM) ->
  describe 'ESM construction', ->
    describe '#new', ->
      it 'should create new ESM'

    describe '#initialize', ->
      it 'should create resources for ESM namespace'

    describe '#destroy', ->
      it 'should destroy resources for ESM namespace'

  describe 'ESMs recommendation methods', ->
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


  describe 'ESM inserting data', ->
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



    describe '#set_action_weight', ->
      it 'should assign an actions weight'

    describe '#get_action_weight', ->
      it 'should return an actions weight'

    describe '#bootstrap', ->
      it 'should add a stream of comma separated events (person,action,thing,created_at,expires_at) to the ESM'

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

  
    