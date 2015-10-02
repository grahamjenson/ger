esm_tests = (ESM) ->
  ns = "default"

  describe 'construction', ->
    describe 'namespace operations', ->
      it '#list_namespaces should list all namespaces', ->
        ns1 = "namespace1"
        ns2 = "namespace2"
        esm = new_esm(ESM) #pass knex as it might be needed
        bb.all([esm.destroy(ns1), esm.destroy(ns2)])
        .then( ->
          esm.list_namespaces()
        )
        .then( (list) ->
          list.should.not.include ns1
          list.should.not.include ns2
        )
        .then( -> bb.all([esm.initialize(ns1), esm.initialize(ns2)]) )
        .then( ->
          esm.list_namespaces()
        )
        .then( (list) ->
          list.should.include ns1
          list.should.include ns2
        )

      it 'should initialize namespace', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal false)
        .then( -> esm.initialize(namespace))
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal true)

      it 'should sucessfully initialize namespace with default', ->
        #based on an error where default is a reserved name in postgres
        namespace = "new_namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal false)
        .then( -> esm.initialize(namespace))
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal true)

      it 'should start with no events', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.initialize(namespace))
        .then( -> esm.count_events(namespace))
        .then( (count) ->
          count.should.equal 0
        )

      it 'should not error out or remove events if re-initialized', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy()
        .then( -> esm.initialize(namespace))
        .then( -> esm.add_event(namespace, 'p','a','t'))
        .then( -> esm.count_events(namespace))
        .then( (count) -> count.should.equal 1)
        .then( -> esm.initialize(namespace))
        .then( -> esm.count_events(namespace))
        .then( (count) -> count.should.equal 1)

      it 'should create resources for ESM namespace', ->
        ns1 = "namespace1"
        ns2 = "namespace2"
        esm = new_esm(ESM) #pass knex as it might be needed
        bb.all([esm.destroy(ns1), esm.destroy(ns2)])
        .then( -> bb.all([esm.initialize(ns1), esm.initialize(ns2)]) )
        .then( ->
          bb.all([
            esm.add_event(ns1, 'p','a','t')
            esm.add_event(ns1, 'p1','a','t')

            esm.add_event(ns2, 'p2','a','t')
          ])
        )
        .then( ->
          bb.all([esm.count_events(ns1), esm.count_events(ns2) ])
        )
        .spread((c1,c2) ->
          c1.should.equal 2
          c2.should.equal 1
        )

      it 'should destroy should not break if resource does not exist', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.destroy(namespace))

  describe 'recommendation methods', ->

    describe '#thing_neighbourhood', ->

      it 'should limit its search to event number of neighbourhood_search_size', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', created_at: today)
            esm.add_event(ns,'p2','view','t1', created_at: yesterday)

            esm.add_event(ns,'p1','view','t2', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t3', expires_at: tomorrow)
          ])
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'], {neighbourhood_search_size: 1})
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].thing.should.equal 't2'
          )
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'], {neighbourhood_search_size: 2})
          )
          .then( (things) ->
            things.length.should.equal 2
          )

      it 'should return a list of objects with thing, max_created_at, max_expires_at', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','view','t2', expires_at: tomorrow)
          ])
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].thing.should.equal 't2'
          )

      it 'should return a list of people who actioned thing', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','view','t2', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t2', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t3', expires_at: tomorrow)
          ])
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'])
          )
          .then( (things) ->
            things.length.should.equal 2
            things[0].people.length.should.equal 2
            things[0].people.should.include 'p1'
            things[0].people.should.include 'p2'
          )

      it 'should return a list of unique people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','view','t2', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t2', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t3', expires_at: tomorrow)
          ])
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'])
          )
          .then( (things) ->
            things.length.should.equal 2
            things[0].people.length.should.equal 2
            things[0].people.should.include 'p1'
            things[0].people.should.include 'p2'
          )
      it 'should not list things twice', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','v','a', expires_at: tomorrow),
            esm.add_event(ns,'p1','b','b', expires_at: tomorrow),
            esm.add_event(ns,'p1','v','b', expires_at: tomorrow),
          ])
          .then(-> esm.thing_neighbourhood(ns, 'a', ['v','b']))
          .then((neighbourhood) ->
            neighbourhood.length.should.equal 1
            neighbourhood[0].thing.should.equal 'b'
          )

      it 'should list recommendable things', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','v','a', expires_at: tomorrow),
            esm.add_event(ns,'p1','v','b', expires_at: tomorrow)
            esm.add_event(ns,'p1','v','c', expires_at: yesterday)
            esm.add_event(ns,'p1','v','d')
          ])
          .then(-> esm.thing_neighbourhood(ns, 'a', ['v']))
          .then((neighbourhood) ->
            neighbourhood.length.should.equal 1
            neighbourhood[0].thing.should.equal 'b'
          )

      it 'should order the things by how many people actioned it', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','v','a', created_at: last_week, expires_at: tomorrow),
            esm.add_event(ns,'p2','v','a', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p3','v','a', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p1','v','b', expires_at: tomorrow),
            esm.add_event(ns,'p2','v','c', expires_at: tomorrow)
            esm.add_event(ns,'p3','v','c', expires_at: tomorrow)
          ])
          .then(-> esm.thing_neighbourhood(ns, 'a', ['v']))
          .then((neighbourhood) ->
            neighbourhood.length.should.equal 2
            neighbourhood[0].thing.should.equal 'c'
            neighbourhood[0].people.length.should.equal 2
            neighbourhood[1].thing.should.equal 'b'
            neighbourhood[1].people.length.should.equal 1
          )

      it 'should return the last_expires_at and last_actioned_at', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','v','a')
            esm.add_event(ns,'p2','v','a')
            esm.add_event(ns,'p3','v','a')
            esm.add_event(ns,'p1','v','b', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p2','v','b', created_at: today, expires_at: yesterday),
            esm.add_event(ns,'p3','v','b', created_at: last_week)
          ])
          .then(-> esm.thing_neighbourhood(ns, 'a', ['v']))
          .then((neighbourhood) ->
            neighbourhood.length.should.equal 1
            neighbourhood[0].thing.should.equal 'b'
            neighbourhood[0].last_actioned_at.getTime().should.equal today.toDate().getTime()
            neighbourhood[0].last_expires_at.getTime().should.equal tomorrow.toDate().getTime()
          )

      it 'should return a unique list of the people that actioned the things (and ordered by number of people)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','v','a')
            esm.add_event(ns,'p2','v','a')
            esm.add_event(ns,'p1','v','b', expires_at: tomorrow),
            esm.add_event(ns,'p1','x','b', expires_at: tomorrow),
            esm.add_event(ns,'p2','v','b', expires_at: tomorrow),
            esm.add_event(ns,'p1','v','c', expires_at: tomorrow),
            esm.add_event(ns,'p3','v','c')
          ])
          .then(-> esm.thing_neighbourhood(ns, 'a', ['v', 'x']))
          .then((neighbourhood) ->
            neighbourhood.length.should.equal 2
            neighbourhood[0].thing.should.equal 'b'
            neighbourhood[1].thing.should.equal 'c'

            neighbourhood[0].people.length.should.equal 2
            neighbourhood[0].people.should.include 'p1'
            neighbourhood[0].people.should.include 'p2'

            neighbourhood[1].people.length.should.equal 1
            neighbourhood[1].people.should.include 'p1'
          )


    describe '#calculate_similarities_from_thing', ->
      it 'more similar histories should be greater', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1')
            esm.add_event(ns,'p2','a','t1')

            esm.add_event(ns,'p1','a','t2')
            esm.add_event(ns,'p2','a','t2')

            esm.add_event(ns,'p2','a','t3')
          ])
          .then( -> esm.calculate_similarities_from_thing(ns, 't1',['t2','t3'],{a: 1}))
          .then( (similarities) ->
            similarities['t3'].should.be.lessThan(similarities['t2'])
          )

    describe '#person_neighbourhood' , ->
      it 'should return a list of similar people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','buy','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','buy','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view', 'buy'])
          )
          .then( (people) ->
            people.length.should.equal 1
          )

      it 'should not return people who have no unexpired events (i.e. potential recommendations) or in actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p3','view','t1', expires_at: yesterday)
            esm.add_event(ns,'p4','view','t1')
            esm.add_event(ns,'p5','view','t1')
            esm.add_event(ns,'p5','likes','t2', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view','buy'])
          )
          .then( (people) ->
            people.length.should.equal 1
          )

      it 'should not return more people than limited', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p3','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p4','view','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view','buy'], {neighbourhood_size: 1})
          )
          .then( (people) ->
            people.length.should.equal 1
            esm.person_neighbourhood(ns, 'p1', ['view','buy'], {neighbourhood_size: 2})
          )
          .then( (people) ->
            people.length.should.equal 2
          )

      it 'should not return the given person', ->
        @timeout(360000)
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view'])
          )
          .then( (people) ->
            people.length.should.equal 0
          )

      it 'should only return people related via given actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','buy','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['buy'])
          )
          .then( (people) ->
            people.length.should.equal 0
          )
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view'])
          )
          .then( (people) ->
            people.length.should.equal 0
          )

      it 'should return people with different actions on the same item', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', created_at: yesterday, expires_at: tomorrow)
            esm.add_event(ns,'p1','view','t2', created_at: today, expires_at: tomorrow)

            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p3', 'buy','t2', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view', 'buy'])
          )
          .then( (people) ->
            people.length.should.equal 2
            people.should.contain 'p3'
            people.should.contain 'p2'
          )

      it 'should return people ordered by the similar persons most recent date', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view','buy'])
          )
          .then( (people) ->
            people.length.should.equal 1
            people[0].should.equal 'p2'
          )

      it 'should find similar people across actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','a'),
            esm.add_event(ns, 'p1','view','b'),
            #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
            esm.add_event(ns, 'p2','view','a'),
            esm.add_event(ns, 'p2','view','b'),
            esm.add_event(ns, 'p2','buy','x', created_at: moment().subtract(2, 'days'), expires_at: tomorrow),

            esm.add_event(ns, 'p3','view','a'),
            esm.add_event(ns, 'p3','buy','l', created_at: moment().subtract(3, 'hours'), expires_at: tomorrow),
            esm.add_event(ns, 'p3','buy','m', created_at: moment().subtract(2, 'hours'), expires_at: tomorrow),
            esm.add_event(ns, 'p3','buy','n', created_at: moment().subtract(1, 'hours'), expires_at: tomorrow)
          ])
          .then(-> esm.person_neighbourhood(ns, 'p1', ['buy', 'view']))
          .then((people) ->
            people.length.should.equal 2
          )

      it 'should be able to set current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','a', created_at: moment().subtract(3, 'days')),
            esm.add_event(ns, 'p1','view','b', created_at: moment().subtract(1, 'days')),
            #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
            esm.add_event(ns, 'p2','view','a', created_at: moment().subtract(3, 'days'), expires_at: tomorrow),

            esm.add_event(ns, 'p3','view','b', created_at: moment().subtract(3, 'days'), expires_at: tomorrow)
          ])
          .then(->
            esm.person_neighbourhood(ns, 'p1', ['view'])
          )
          .then((people) ->
            people.length.should.equal 2
            esm.person_neighbourhood(ns, 'p1', ['view'], current_datetime: moment().subtract(2, 'days'))
          )
          .then((people) ->
            people.length.should.equal 1
          )

    describe '#calculate_similarities_from_person', ->
      it 'handle weights of 0 and people with no hisotry, and people with no similar history', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1')
            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p4','a','t2')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2','p3', 'p4'],{a: 0}))
          .then( (similarities) ->
            similarities['p2'].should.equal 0
            similarities['p3'].should.equal 0
            similarities['p4'].should.equal 0
          )

      it 'more similar histories should be greater', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1')
            esm.add_event(ns,'p1','a','t2')

            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p2','a','t2')

            esm.add_event(ns,'p3','a','t1')
            esm.add_event(ns,'p3','a','t3')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],{a: 1}))
          .then( (similarities) ->
            similarities['p3'].should.be.lessThan(similarities['p2'])
          )

      it 'should weight the actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','buy','t2')

            esm.add_event(ns,'p2','view','t1')

            esm.add_event(ns,'p3','buy','t2')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],{view: 1, buy: 5}))
          .then( (similarities) ->
            similarities['p3'].should.be.greaterThan(similarities['p2'])
          )

      it 'should limit similarity measure on similarity_search_size (ordered by created_at)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: today)

            esm.add_event(ns,'p2','a','t3', created_at: today)
            esm.add_event(ns,'p2','a','t1', created_at: yesterday)
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2'], {a: 1}, {similarity_search_size: 1}))
          .then( (similarities) ->
            similarities['p2'].should.equal 0
          )
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2'], {a: 1}, {similarity_search_size: 2}))
          .then( (similarities) ->
            similarities['p2'].should.not.equal 0
          )

      it 'should not limit similarity measure similarity_search_size for non selected actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: today)

            esm.add_event(ns,'p2','b','t3', created_at: today)
            esm.add_event(ns,'p2','a','t1', created_at: yesterday)
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2'], {a: 1}, {similarity_search_size: 1}))
          .then( (similarities) ->
            similarities['p2'].should.not.equal 0
          )

      it 'should handle multiple actions', ->
        #example taken from http://infolab.stanford.edu/~ullman/mmds/ch9.pdf
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'A','r4','HP1')
            esm.add_event(ns,'A','r5','TW')
            esm.add_event(ns,'A','r1','SW1')

            esm.add_event(ns,'B','r5','HP1')
            esm.add_event(ns,'B','r5','HP2')
            esm.add_event(ns,'B','r4','HP3')

            esm.add_event(ns,'C','r2','TW')
            esm.add_event(ns,'C','r4','SW1')
            esm.add_event(ns,'C','r5','SW2')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'A',['B','C'], {r1: -2, r2: -1, r3: 0, r4: 1, r5: 2}))
          .then( (similarities) ->
            similarities['C'].should.be.lessThan(similarities['B'])
          )

      it 'should calculate the similarity between a person and a set of people for a list of actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1'),
            esm.add_event(ns,'p2','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2'],{a: 1}))
          .then( (similarities) ->
            similarities['p2'].should.exist
          )

      it 'should be ale to set current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t2', created_at: today),
            esm.add_event(ns,'p1','view','t1', created_at: three_days_ago),

            esm.add_event(ns,'p2','view','t2', created_at: today),
            esm.add_event(ns,'p2','view','t1', created_at: three_days_ago),

            esm.add_event(ns,'p3','view','t1', created_at: three_days_ago),
          ])
          .then( ->
            esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],
              {view: 1}, { current_datetime: two_days_ago}
            )
          )
          .then( (similarities) ->
            similarities['p3'].should.equal(similarities['p2'])
            esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],
              {view: 1}
            )
          )
          .then( (similarities) ->
            similarities['p2'].should.be.greaterThan(similarities['p3'])
          )

      describe "recent events", ->
        it 'if p1 viewed a last week and b today, a person closer to b should be more similar', ->
          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','view','a', created_at: moment().subtract(7, 'days')),
              esm.add_event(ns,'p1','view','b', created_at: today),

              esm.add_event(ns,'p2','view','b', created_at: today),
              esm.add_event(ns,'p3','view','a', created_at: today)

            ])
            .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'], {view: 1}, event_decay_rate: 1.05))
            .then( (similarities) ->
              similarities['p3'].should.be.lessThan(similarities['p2'])
            )

        it 'should calculate the recent event decay weight relative to current_datetime', ->
          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','view','a', created_at: today),
              esm.add_event(ns,'p1','view','b', created_at: today),

              esm.add_event(ns,'p2','view','b', created_at: yesterday),
              esm.add_event(ns,'p2','view','a', created_at: today),

              #all actions but one day offset
              esm.add_event(ns,'p1`','view','a', created_at: yesterday),
              esm.add_event(ns,'p1`','view','b', created_at: yesterday),

              esm.add_event(ns,'p2`','view','b', created_at: two_days_ago),
              esm.add_event(ns,'p2`','view','a', created_at: yesterday),
            ])
            .then( ->
              sim_today = esm.calculate_similarities_from_person(ns, 'p1',['p2'], {view: 1},
                event_decay_rate: 1.2, current_datetime: today)
              sim_yesterday = esm.calculate_similarities_from_person(ns, 'p1`',['p2`'], {view: 1},
                event_decay_rate: 1.2, current_datetime: yesterday)
              bb.all([sim_today, sim_yesterday])
            )
            .spread( (s1, s2) ->
              s1['p2'].should.equal(s2['p2`'])
            )

      it 'should not be effected by having same events (through add_event)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1'),
            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p3','a','t1')
            esm.add_event(ns,'p3','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],{a: 1}))
          .then( (similarities) ->
            similarities['p2'].should.equal similarities['p3']
          )


      it 'should not be effected by having bad names', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,"'p\n,1};","v'i\new","'a\n;"),
            esm.add_event(ns,"'p\n2};","v'i\new","'a\n;")
          ])
          .then(-> esm.calculate_similarities_from_person(ns, "'p\n,1};",["'p\n2};"], {"v'i\new": 1}))
          .then((similarities) ->
            similarities["'p\n2};"].should.be.greaterThan(0)
          )

    describe '#recent_recommendations_by_people', ->

      # TODO multiple returned things
      # it 'should return multiple things for multiple actions', ->
      #   init_esm(ESM, ns)
      #   .then (esm) ->
      #     bb.all([
      #       esm.add_event(ns,'p1','a1','t1', expires_at: tomorrow),
      #       esm.add_event(ns,'p1','a2','t1', expires_at: tomorrow)
      #     ])
      #     .then( -> esm.recent_recommendations_by_people(ns, ['a1', 'a2'], ['p1']))
      #     .then( (people_recommendations) ->
      #       people_recommendations['p1']['a1'].length.should.equal 1
      #       people_recommendations['p1']['a2'].length.should.equal 1
      #     )

      it 'should only return things created before current_datetime', ->
        a2daysago = moment().subtract(2, 'days')
        a3daysago = moment().subtract(3, 'days')
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: today, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t3', created_at: a2daysago, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t4', created_at: a3daysago, expires_at: tomorrow),
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a'], ['p1']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 4

            esm.recent_recommendations_by_people(ns, ['a'], ['p1'], current_datetime: yesterday)
          )
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 3
            esm.recent_recommendations_by_people(ns, ['a'], ['p1'], current_datetime: a2daysago)
          )
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
          )


      it 'should return multiple things for multiple actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a1','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a2','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a1', 'a2'], ['p1']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
          )

      it 'should return things for multiple actions and multiple people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a1','t1', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p2','a2','t2', created_at: today, expires_at: tomorrow)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a1', 'a2'] ,['p1', 'p2']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
            people_recommendations[0].person.should.equal 'p2'
            people_recommendations[0].thing.should.equal 't2'

            people_recommendations[1].person.should.equal 'p1'
            people_recommendations[1].thing.should.equal 't1'
          )

      it 'should return things for multiple people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p2','a','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a'] ,['p1', 'p2']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
          )

      it 'should not return things without expiry date', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2')
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a'], ['p1']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 1
          )

      it 'should not return expired things', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', expires_at: yesterday)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a'], ['p1']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 1
          )


      it 'should return the same item for different people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a1','t', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p2','a2','t', created_at: today, expires_at: tomorrow)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a1', 'a2'] ,['p1', 'p2']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
            people_recommendations[0].person.should.equal 'p2'
            people_recommendations[0].thing.should.equal 't'

            people_recommendations[1].person.should.equal 'p1'
            people_recommendations[1].thing.should.equal 't'
          )

      it 'should be limited by related things limit', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', expires_at: tomorrow),
            esm.add_event(ns,'p2','a','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recent_recommendations_by_people(ns, ['a'],['p1','p2'], {recommendations_per_neighbour: 1}))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 2
          )



      it 'should return the last_actioned_at last_expires_at', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p1','a','t1', created_at: yesterday, expires_at: tomorrow)
          .then( ->
            esm.add_event(ns,'p1','a','t1', created_at: today, expires_at: next_week)
          )
          .then( -> esm.recent_recommendations_by_people(ns, ['a'], ['p1', 'p2']))
          .then( (people_recommendations) ->
            people_recommendations.length.should.equal 1
            people_recommendations[0].last_expires_at.getTime().should.equal next_week.toDate().getTime()
            people_recommendations[0].last_actioned_at.getTime().should.equal today.toDate().getTime()
          )

      describe 'time_until_expiry', ->

        it 'should not return things that expire before the date passed', ->

          a1day = moment().add(1, 'days').format()
          a2days = moment().add(2, 'days').format()
          a3days = moment().add(3, 'days').format()

          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','a','t1', expires_at: a3days),
              esm.add_event(ns,'p2','a','t2', expires_at: a1day)
            ])
            .then( -> esm.recent_recommendations_by_people(ns, ['a'],['p1','p2'], { time_until_expiry: 48*60*60}))
            .then( (people_recommendations) ->
              people_recommendations.length.should.equal 1
            )


    describe '#filter_things_by_previous_actions', ->
      it 'should remove things that a person has previously actioned', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].should.equal 't2'
          )

      it 'should filter things only for given actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','buy','t2')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].should.equal 't2'
          )

      it 'should filter things for multiple actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','buy','t2')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view', 'buy'])
          )
          .then( (things) ->
            things.length.should.equal 0
          )

  describe 'inserting data', ->
    describe '#add_events', ->
      it 'should add an events to the ESM', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_events([{namespace: ns, person: 'p', action: 'a', thing: 't'}])
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
          )

      it 'should add multiple events to the ESM', ->
        exp_date = (new Date()).toISOString()
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_events([
            {namespace: ns, person: 'p1', action: 'a', thing: 't1'}
            {namespace: ns, person: 'p1', action: 'a', thing: 't2', created_at: new Date().toISOString()}
            {namespace: ns, person: 'p1', action: 'a', thing: 't3', expires_at: exp_date}
          ])
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 3
            esm.find_events(ns, person: 'p1', action: 'a', thing: 't3')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
            event.expires_at.toISOString().should.equal exp_date
          )


    describe '#add_event', ->
      it 'should add an event to the ESM', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
          )

    describe '#count_events', ->
      it 'should return the number of events in the event store', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
          )

    describe '#estimate_event_count', ->
      it 'should be a fast estimate of events', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','view','t3')
          ])
          .then( ->
            esm.pre_compact(ns)
          )
          .then( ->
            esm.estimate_event_count(ns)
          )
          .then( (count) ->
            count.should.equal 3
          )

    describe '#delete_events', ->
      it "should return 0 if no events are deleted", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.delete_events(ns,  person: 'p1', action: 'view', thing: 't1')
          .then( (ret) ->
            ret.deleted.should.equal 0
          )

      it "should delete events from esm", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns, person: 'p1', action: 'view', thing: 't1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 1
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 2
          )

      it "should delete events from esm for person", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns,  person: 'p1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 0
          )

      it "should delete events from esm for action", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns, action: 'view')
          )
          .then( (ret) ->
            ret.deleted.should.equal 2
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 1
          )

      it "should delete all events if no value is given", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns)
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 0
          )

    describe '#find_events', ->
      it 'should return the event', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.person.should.equal 'p'
            event.action.should.equal 'a'
            event.thing.should.equal 't'
          )

      it "should return null if no event matches", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          .then( (events) ->
            events.length.should.equal 0
          )

      it "should find event with only one argument", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            bb.all([
              esm.find_events(ns, person: 'p')
              esm.find_events(ns, action: 'a')
              esm.find_events(ns, thing: 't')
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
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            bb.all([
              esm.find_events(ns, person: 'p1')
              esm.find_events(ns, person:'p1', action: 'view')
              esm.find_events(ns, person:'p1', action: 'view', thing: 't1')
              esm.find_events(ns, action: 'view')
              esm.find_events(ns, person: 'p1', thing:'t1')
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
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_events([
            {namespace: ns, person:'bob', action: 'hates', thing: 'hobbit', created_at: yesterday},
            {namespace: ns, person:'bob', action: 'likes', thing: 'hobbit', created_at: today},
          ])
          .then( ->
            esm.find_events(ns, person: 'bob', size: 1, current_datetime: undefined)
          )
          .then( (events) ->
            events.length.should.equal 1
            events[0].action.should.equal 'likes'

          )

      it "should return only the most recent unique events", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p1','a','t1', created_at: yesterday)
          .then( ->
            esm.add_event(ns,'p1','a','t1', created_at: today)
          )
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 1
            moment(events[0].created_at).format().should.equal today.format()
            events[0].thing.should.equal 't1'
          )

      it "should limit the returned events to size", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns,'p1','a','t3', created_at: moment().subtract(10, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1', size: 2)
          )
          .then( (events) ->
            events.length.should.equal 2
            events[0].thing.should.equal 't1'
            events[1].thing.should.equal 't2'
          )

      it "should return pagable events", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','a','t1', created_at: new Date()),
            esm.add_event(ns, 'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns, 'p1','a','t3', created_at: moment().subtract(10, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1', size: 2, page: 1)
          )
          .then( (events) ->
            events.length.should.equal 1
            events[0].thing.should.equal 't3'
          )

      it 'should be able to take arrays', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
            esm.add_event(ns,'p2','view','t1')
          ])
          .then( ->
            bb.all([
              esm.find_events(ns, people: ['p1', 'p2'])
              esm.find_events(ns, person: 'p1', actions: ['view', 'like'])
              esm.find_events(ns, person: 'p1', action: 'view', things: ['t1','t2'])
            ])
          )
          .spread( (events1, events2, events3) ->
            events1.length.should.equal 4
            events2.length.should.equal 3
            events3.length.should.equal 2
          )

      it 'should be able to select current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns,'p1','a','t3', created_at: moment().subtract(6, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            esm.find_events(ns, person: 'p1', current_datetime: moment().subtract(1, 'days'))
          )
          .then( (events) ->
            events.length.should.equal 2
            esm.find_events(ns, person: 'p1', current_datetime: moment().subtract(3, 'days'))
          )
          .then( (events) ->
            events.length.should.equal 1
          )

      it 'should be able to select time_until_expiry', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: today),
            esm.add_event(ns,'p1','a','t2', expires_at: moment(today).add(10, 'minutes'))
            esm.add_event(ns,'p1','a','t3', expires_at: moment(today).add(100, 'minutes'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            esm.find_events(ns, person: 'p1', time_until_expiry: 60)
          )
          .then( (events) ->
            events.length.should.equal 2
            esm.find_events(ns, person: 'p1', time_until_expiry: 630)
          )
          .then( (events) ->
            events.length.should.equal 1
          )



module.exports = esm_tests;


