actions = ["buy", "like", "view"]
people = [1..1000]
things = [1..100]

esm_tests = (ESM) ->
  describe 'performance tests', ->
    naction = 200
    nevents = 2000
    nbevents = 20000
    ncompact = 3
    nrecommendations = 50

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
        bb.try( ->

          st = new Date().getTime()

          promises = []
          for x in [1..naction]
            promises.push ger.action(sample(actions) , sample([1..10]))
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/naction
            console.log "#{pe}ms per action"
          )
        )
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

