actions = ["buy", "like", "view"]
people = [1..1000]
things = [1..100]

describe 'performance tests', ->

  it 'adding 1000 events takes so much time', ->
    console.log ""
    console.log ""
    console.log "####################################################"
    console.log "################# Performance Tests ################"
    console.log "####################################################"
    console.log ""
    console.log ""
    this.timeout(60000);
    init_ger()
    .then((ger) ->
      bb.try( ->

        st = new Date().getTime()
        
        promises = []
        for x in [1..100]
          promises.push ger.action(sample(actions) , sample([1..10]))
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/100
          console.log "#{pe}ms per action"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..2000]
          promises.push ger.event(sample(people), sample(actions) , sample(things))
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/2000
          console.log "#{pe}ms per event"
        )
      )
      .then( ->
        st = new Date().getTime()

        rs = new Readable();
        for x in [1..20000]
          rs.push("#{sample(people)},#{sample(actions)},#{sample(things)},2014-01-01,\n")
        rs.push(null);

        ger.bootstrap(rs)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/20000
          console.log "#{pe}ms per bootstrapped event"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..3]
          promises.push ger.compact_database()

        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/3
          console.log "#{pe}ms for compact"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..25]
          promises.push ger.weighted_similar_people(sample(people), sample(actions))
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/25
          console.log "#{pe}ms per weighted_similar_people"
        )
      )
      .then( ->
        st = new Date().getTime()
        promises = []
        for x in [1..25]
          promises.push ger.recommendations_for_person(sample(people), sample(actions))
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/25
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
