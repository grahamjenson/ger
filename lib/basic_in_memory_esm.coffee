bb = require 'bluebird'
_ = require 'underscore'

event_store = {}
person_action_store = {}
thing_action_store = {}

actions_store = {}

class BasicInMemoryESM

  constructor: (@_namespace = 'public', options = {}) ->

  initialize: ->
    event_store[@_namespace] = []
    person_action_store[@_namespace] = {}
    thing_action_store[@_namespace] = {}
    actions_store[@_namespace] = {}

  destroy: ->
    delete event_store[@_namespace]
    delete person_action_store[@_namespace]
    delete thing_action_store[@_namespace]
    delete actions_store[@_namespace]

  get_actions: ->
    action_weights = ({key: action, weight: weight} for action, weight of actions_store[@_namespace])
    action_weights = _.sortBy(action_weights, (x) -> - x.weight)
    return bb.try(-> action_weights)

  _person_history_for_action: (person, action) ->
    return [] if person_action_store[@_namespace][person] == undefined or person_action_store[@_namespace][person][action] == undefined
    events = (event for thing, event of person_action_store[@_namespace][person][action])  
    return _.sortBy(events, (x) -> - x.created_at.getTime())

  _thing_history_for_action: (thing, action) ->
    return [] if thing_action_store[@_namespace][thing] == undefined or thing_action_store[@_namespace][thing][action] == undefined
    events = (event for person, event of thing_action_store[@_namespace][thing][action])  
    return _.sortBy(events, (x) -> - x.created_at.getTime())

  _find_similar_people_for_action: (person, action_to_search, action_to_do, person_history_limit) ->
    #find things the person has actioned
    person_history = @_person_history_for_action(person, action_to_search)
    things = (e.thing for e in person_history)
    #find people who have also actioned that thing
    people = []
    for t in things
      thing_history = @_thing_history_for_action(t, action_to_search)
      people = people.concat (e.person for e in thing_history)

    #filter those people if they havent done action_to_do
    people = people.filter((p) => !!person_action_store[@_namespace][p] && !!person_action_store[@_namespace][p][action_to_do])
    people

  find_similar_people: (person, actions, action_to_do, similar_people_limit = 100, person_history_limit = 500) ->
    return bb.try(-> []) if !actions or actions.length == 0

    people = []
    for action_to_search in actions
      people = people.concat @_find_similar_people_for_action(person, action_to_search, action_to_do, person_history_limit)
    people = people.filter((p) -> p != person)

    return bb.try(-> _.uniq(people))

  calculate_similarities_from_person: (person, people, actions, person_history_limit, recent_event_days) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or people.length == 0
    return bb.try(-> {})

  recently_actioned_things_by_people: (action, people, related_things_limit) ->
    return bb.try(->[]) if people.length == 0
    things = {}
    for person in people
      history = @_person_history_for_action(person, action)[..related_things_limit]
      things[person] = ({thing: event.thing, last_actioned_at: event.created_at} for event in history)

    bb.try(-> things)

  person_history_count: (person) ->
    things = []
    for action, thing_events of person_action_store[@_namespace][person]
      things = things.concat(Object.keys(thing_events))

    return bb.try(-> _.uniq(things).length)


  filter_things_by_previous_actions: (person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0
    return bb.try(-> things)

  add_event: (person, action, thing, dates = {}) ->
    created_at = dates.created_at || new Date()
    e = {person: person, action: action, thing: thing, created_at: created_at, expires_at: dates.expires_at}
    
    event_store[@_namespace].push e

    person_action_store[@_namespace][person] ||= {}
    person_action_store[@_namespace][person][action] ||= {}
    person_action_store[@_namespace][person][action][thing] = e

    thing_action_store[@_namespace][thing] ||= {}
    thing_action_store[@_namespace][thing][action] ||= {}
    thing_action_store[@_namespace][thing][action][person] = e

    bb.try(-> true)

  count_events: ->
    return bb.try(=>  event_store[@_namespace].length)

  estimate_event_count: ->
    return bb.try(=> event_store[@_namespace].length)

  find_event: (person, action, thing) ->
    return bb.try(-> null) if not person_action_store[@_namespace][person]
    return bb.try(-> null) if not person_action_store[@_namespace][person][action]
    return bb.try(-> null) if not person_action_store[@_namespace][person][action][thing]
    return bb.try(=> person_action_store[@_namespace][person][action][thing])

  set_action_weight: (action, weight) ->
    actions_store[@_namespace][action] = weight
    bb.try(-> true)

  get_action_weight: (action) ->
    bb.try(-> actions_store[@_namespace][action])

  bootstrap: (stream) ->

  pre_compact: ->

  compact_people: ->

  compact_things: ->

  expire_events: ->

  post_compact: ->

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return BasicInMemoryESM)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = BasicInMemoryESM;
