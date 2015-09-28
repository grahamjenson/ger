actions = [ "view"]
people = [1..10]
things = [1..10]

ns = global.default_namespace

random_created_at = ->
  moment().subtract(_.random(0, 120), 'minutes')

compact= (ger) ->

  ger.compact_database(ns, {
    compact_database_person_action_limit: 10,
    compact_database_thing_action_limit: 10,
    actions: actions
  })

add_events= (ger, n=500) ->
  events = []
  for y in [1..n]
    events.push {namespace: ns, person: sample(people), action: sample(actions), thing: sample(things),created_at: random_created_at(), expires_at: tomorrow}
  ger.events(events)

recommend = (ger) ->

  ger.recommendations_for_person(ns, sample(people), actions: {buy:5, like:3, view:1})

describe 'all together tests', ->
  ncompacts = 4
  nevents = 30
  nrecs = 30

  it "should not break when all functions are running at the same time", ->
    self = @
    console.log ""
    console.log ""
    console.log "####################################################"
    console.log "################ All Together Tests ################"
    console.log "####################################################"
    console.log ""
    console.log ""
    time = 5000
    @timeout(time + (20*1000))

    init_ger()
    .then((ger) ->
      #10 seconds of thrashing

      promises = []

      for n in [1..ncompacts]
        diff = time/ncompacts
        d = diff*n
        promises.push bb.delay(d).then( -> compact(ger))

      for n in [1..nevents]
        diff = time/nevents
        d = diff*n
        promises.push  bb.delay(d).then( -> add_events(ger))

      for n in [1..nrecs]
        diff = time/nrecs
        d = diff*n
        promises.push  bb.delay(d).then( -> recommend(ger))

      bb.all(promises)

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
