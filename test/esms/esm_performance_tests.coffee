actions = ["buy", "like", "view"]
people = [1..1000]
things = [1..100]

esm_tests = (ESM) ->
  describe 'performance tests', ->
    ns = 'default'

    naction = 50
    nevents = 500
    nevents_diff = 25
    nbevents = 5000
    nfindpeople = 100
    ncalcpeople = 100
    ncompact = 2
    nrecommendations = 20

    it "adding #{nevents} events takes so much time", ->
      self = @
      console.log ""
      console.log ""
      console.log "####################################################"
      console.log "################# Performance Tests ################"
      console.log "####################################################"
      console.log ""
      console.log ""
      @timeout(360000)
      init_ger(ESM, ns)
      .then((ger) ->
        st = new Date().getTime()
        promises = []
        for x in [1..nevents]
          promises.push ger.event(ns, sample(people), sample(actions) , sample(things), expires_at: tomorrow)
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/nevents
          console.log "#{pe}ms per event"
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nevents/nevents_diff]
            events = []
            for y in [1..nevents_diff]
              events.push {namespace: ns, person: sample(people), action: sample(actions), thing: sample(things), expires_at: tomorrow}
            promises.push ger.events(events)
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nevents
            console.log "#{pe}ms adding events in #{nevents_diff} per set"
          )
        )
        .then( ->
          st = new Date().getTime()

          rs = new Readable();
          for x in [1..nbevents]
            rs.push("#{sample(people)},#{sample(actions)},#{sample(things)},2014-01-01,2050-01-01\n")
          rs.push(null);

          ger.bootstrap(ns, rs)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nbevents
            console.log "#{pe}ms per bootstrapped event"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..ncompact]
            promises.push ger.compact_database(ns, actions: actions)

          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/ncompact
            console.log "#{pe}ms for compact"
          )
        )
        .then( ->
          st = new Date().getTime()

          promises = []
          for x in [1..nfindpeople]
            promises.push ger.esm.find_similar_people(ns, sample(people), actions)
          bb.all(promises)

          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nfindpeople
            console.log "#{pe}ms per find_similar_people"
          )
        )
        .then( ->
          st = new Date().getTime()

          promises = []
          for x in [1..ncalcpeople]
            peeps = _.unique((sample(people) for i in [0..10]))
            promises.push ger.esm.calculate_similarities_from_person(ns, peeps[0], peeps[1..-1] , actions, 500, 5)
          bb.all(promises)

          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/ncalcpeople
            console.log "#{pe}ms per calculate_similarities_from_person"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nrecommendations]
            promises.push ger.recommendations_for_person(ns, sample(people), actions: {buy:5, like:3, view:1})
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nrecommendations
            console.log "#{pe}ms per recommendations_for_person"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nrecommendations]
            promises.push ger.recommendations_for_thing(ns, sample(things), actions: {buy:5, like:3, view:1})
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nrecommendations
            console.log "#{pe}ms per recommendations_for_thing"
          )
        )
      )
      .then( ->
        console.log ""
        console.log ""
        console.log "####################################################"
        console.log "################# END OF Performance Tests #########"
        console.log "####################################################"
        console.log ""
        console.log ""
      )

for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)

