actions = ["buy", "like", "view"]
people = [1..1000]
things = [1..100]

esm_tests = (ESM) ->
  describe 'performance tests', ->
    naction = 50
    nevents = 5000
    nbevents = 10000
    nfindpeople = 100
    ncalcpeople = 100
    ncompact = 3
    nrecommendations = 100

    it 'adding 1000 events takes so much time', ->
      self = @
      console.log ""
      console.log ""
      console.log "####################################################"
      console.log "################# Performance Tests ################"
      console.log "####################################################"
      console.log ""
      console.log ""
      @timeout(360000)
      init_ger(ESM)
      .then((ger) ->
        bb.all([
          ger.action("buy" , 5),
          ger.action("like" , 3),
          ger.action("view" , 2),
        ])
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nevents]
            promises.push ger.event(sample(people), sample(actions) , sample(things))
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nevents
            console.log "#{pe}ms per event"
          )
        )
        .then( ->
          st = new Date().getTime()

          rs = new Readable();
          for x in [1..nbevents]
            rs.push("#{sample(people)},#{sample(actions)},#{sample(things)},2014-01-01,\n")
          rs.push(null);

          ger.bootstrap(rs)
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
            promises.push ger.compact_database()

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
            promises.push ger.esm.find_similar_people(sample(people), actions, sample(actions))
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
            promises.push ger.esm.calculate_similarities_from_person(peeps[0], peeps[1..-1] , actions, 500, 5)
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
            promises.push ger.recommendations_for_person(sample(people), sample(actions))
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nrecommendations
            console.log "#{pe}ms per recommendations_for_person"
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

