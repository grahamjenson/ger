ger_tests = (ESM) ->
  actions = [ "view"]
  people = [1..10]
  things = [1..10]

  ns = global.default_namespace
  log = false
  random_created_at = ->
    moment().subtract(_.random(0, 120), 'minutes')

  compact= (ger) ->

    ger.compact_database(ns, {
      compact_database_person_action_limit: 10,
      compact_database_thing_action_limit: 10,
      actions: actions
    }).then( -> console.log 'finish compact' if log)

  add_events= (ger, n=100) ->
    events = []
    for y in [1..n]
      events.push {namespace: ns, person: _.sample(people), action: _.sample(actions), thing: _.sample(things),created_at: random_created_at(), expires_at: tomorrow}
    ger.events(events).then( -> console.log 'finish events' if log)

  recommend = (ger) ->
    ger.recommendations_for_person(ns, _.sample(people), actions: {buy:5, like:3, view:1}).then( -> console.log 'finish recs' if log)

  describe 'Async Method Tests', ->


    it "should not break when all functions are running at the same time", ->
      self = @
      console.log ""
      console.log ""
      console.log "####################################################"
      console.log "############## Async          Tests ################"
      console.log "####################################################"
      console.log ""
      console.log ""
      time = 500
      @timeout(time + (20*1000))
      n = 5
      init_ger(ESM)
      .then((ger) ->

        promises = []

        for i in [1..n]
          promises.push compact(ger).then( -> add_events(ger)).then( -> recommend(ger))
          promises.push compact(ger).then( -> recommend(ger)).then( -> add_events(ger))
          promises.push add_events(ger).then( -> recommend(ger)).then( -> compact(ger))
          promises.push add_events(ger).then( -> compact(ger)).then( -> recommend(ger))
          promises.push recommend(ger).then( -> compact(ger)).then( -> add_events(ger))
          promises.push recommend(ger).then( -> add_events(ger)).then( -> compact(ger))

        bb.all(promises)

      )
      .then( ->
        console.log ""
        console.log ""
        console.log "####################################################"
        console.log "################ END OF Async        Tests #########"
        console.log "####################################################"
        console.log ""
        console.log ""
      )

module.exports = ger_tests;