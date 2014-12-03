esm_tests = (esm) ->
  describe 'ESM construction', ->
    describe 'new', ->
      it 'should create new ESM'

    describe 'initialize', ->
      it 'should create resources for ESM namespace'

    describe 'destroy', ->
      it 'should destroy resources for ESM namespace'

  describe 'ESMs recommendation methods', ->
    describe 'get_actions', ->
      it 'should returns all the assigned actions with weights in descending order', ->
        init_esm(esm)
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

    describe 'find_similar_people' , ->
      it 'should return a list of similar people'

    describe 'calculate_similarities_from_person', ->
      it 'should calculate the distance between a person and a set of people for a list of actions'

    describe 'recently_actioned_things_by_people', ->
      it 'should return a list of things that people have actioned', ->
        init_esm(esm)
        .then (esm) ->
          bb.all([esm.add_event('p1','a','t'),esm.add_event('p2','a','t1')])
          .then( -> esm.recently_actioned_things_by_people('a',['p1','p2']))
          .then( (people_things) ->
            console.log people_things
            people_things['p1'][0].thing.should.equal 't'
            people_things['p1'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't1'
            people_things['p2'].length.should.equal 1
          ) 

      it 'should return the same item for different people', ->
        init_esm(esm)
        .then (esm) ->
          bb.all([esm.add_event('p1','a','t'), esm.add_event('p2','a','t')])
          .then( -> esm.recently_actioned_things_by_people('a',['p1','p2']))
          .then( (people_things) ->
            people_things['p1'][0].thing.should.equal 't'
            people_things['p1'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't'
            people_things['p2'].length.should.equal 1
          ) 

    describe 'person_history_count', ->
      it 'should return the number of things a person has actioned in their history'

    describe 'filter_things_by_previous_actions', ->
      it 'should remove things that a person has previously actioned'


  describe 'ESM inserting data', ->
    describe 'add_event', ->
      it 'should add an event to the ESM'

    describe 'count_events', ->
      it 'should '

    describe 'estimate_event_count', ->
      it 'should be a fast estimate of events' 

    describe 'find_event', ->
      it 'should return the event from the ESM'

    describe 'set_action_weight', ->
      it 'should assign an actions weight'

    describe 'get_action_weight', ->
      it 'should return an actions weight'

    describe 'bootstrap', ->
      it 'should add a stream of comma separated events (person,action,thing,created_at,expires_at) to the ESM'

  describe 'ESM compacting database', ->
    describe 'pre_compact', ->
      it 'should prepare the ESM for compaction'

    describe 'compact_people', ->
      it 'should truncate the events of peoples history'

    describe 'compact_things', ->
      it 'should truncate the events of things history'

    describe 'expire_events', ->
      it 'should remove events that have expired'

    describe 'post_compact', ->
      it 'should perform tasks after compaction'


for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)

  
    