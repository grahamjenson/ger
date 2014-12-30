bb = require 'bluebird'
_ = require 'underscore'
split = require 'split'

moment = require 'moment'

event_store = {}
person_action_store = {}
thing_action_store = {}

actions_store = {}

#This is a simple implementation of an ESM to demonstrate the API and NOT FOR PRODUCTION PURPOSES
class BasicInMemoryESM

  constructor: (@_namespace = 'public', options = {}) ->

  initialize: ->
    event_store[@_namespace] ||= []
    person_action_store[@_namespace] ||= {}
    thing_action_store[@_namespace] ||= {}
    actions_store[@_namespace] ||= {}
    bb.try(-> )

  destroy: ->
    delete event_store[@_namespace]
    delete person_action_store[@_namespace]
    delete thing_action_store[@_namespace]
    delete actions_store[@_namespace]
    bb.try(-> )

  exists: ->
    bb.try(=> !!event_store[@_namespace])

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

  _recent_jaccard_distance: (p1, p2, action, days) ->
    recent_date = moment().subtract(days, 'days').toDate()

    p1_things = @_person_history_for_action(p1,action).filter((e) -> e.created_at > recent_date).map((e) -> e.thing)
    p2_things = @_person_history_for_action(p2,action).filter((e) -> e.created_at > recent_date).map((e) -> e.thing)

    jaccard = (_.intersection(p1_things, p2_things).length)/(_.union(p1_things, p2_things).length)
    jaccard = 0 if isNaN(jaccard)
    return jaccard

  _jaccard_distance: (p1, p2, action) ->
    p1_things = @_person_history_for_action(p1,action).map((e) -> e.thing)
    p2_things = @_person_history_for_action(p2,action).map((e) -> e.thing)
    jaccard = (_.intersection(p1_things, p2_things).length)/(_.union(p1_things, p2_things).length)
    jaccard = 0 if isNaN(jaccard)
    return jaccard

  calculate_similarities_from_person: (person, people, actions, person_history_limit=100, recent_event_days= 14) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or people.length == 0
    similarities = {}
    for p in people
      similarities[p] = {}
      for action in actions
        jaccard = @_jaccard_distance(person, p, action)
        recent_jaccard = @_recent_jaccard_distance(person, p, action, recent_event_days)
        similarities[p][action] = ((recent_jaccard * 4) + (jaccard * 1))/5.0

    return bb.try(-> similarities)

  recently_actioned_things_by_people: (action, people, related_things_limit) ->
    return bb.try(->[]) if people.length == 0
    things = {}
    for person in people
      history = @_person_history_for_action(person, action)[...related_things_limit]
      things[person] = ({thing: event.thing, last_actioned_at: event.created_at} for event in history)

    bb.try(-> things)

  person_history_count: (person) ->
    things = []
    for action, thing_events of person_action_store[@_namespace][person]
      things = things.concat(Object.keys(thing_events))

    return bb.try(-> _.uniq(things).length)


  _filter_things_by_previous_action: (person, things, action) ->
    things.filter((t) => !person_action_store[@_namespace][person] or !person_action_store[@_namespace][person][action] or !person_action_store[@_namespace][person][action][t])

  filter_things_by_previous_actions: (person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0
    filtered_things = things
    for action in actions
      filtered_things = _.intersection(filtered_things, @_filter_things_by_previous_action(person, things, action))
    return bb.try(-> filtered_things)

  add_event: (person, action, thing, dates = {}) ->
    created_at = dates.created_at || new Date()
    expires_at = if dates.expires_at then new Date(dates.expires_at) else null
    found_event = @_find_event(person, action, thing)

    if found_event
      found_event.created_at = if created_at > found_event.created_at then created_at else found_event.created_at
      found_event.expires_at = if expires_at && expires_at > found_event.expires_at then expires_at else found_event.expires_at
    else
      e = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
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

  _find_event: (person, action, thing) ->
    return null if not person_action_store[@_namespace][person]
    return null if not person_action_store[@_namespace][person][action]
    return null if not person_action_store[@_namespace][person][action][thing]
    return person_action_store[@_namespace][person][action][thing]

  _find_events: (person, action, thing) ->
    #returns all events fitting the above description
    events = []
    for e in event_store[@_namespace]
      add = true
      add = false if person and person != e.person
      add = false if action and action != e.action
      add = false if thing and thing != e.thing
      events.push e if add
    events = _.sortBy(events, (x) -> - x.created_at.getTime())

    return events

  find_events: (person, action, thing, options = {}) ->
    options = _.defaults(options, {size: 50, page: 0})
    size = options.size
    page = options.page

    events = @_find_events(person, action, thing)
    events = events[size*page ... size*(page+1)]
    return bb.try(=> events)

  set_action_weight: (action, weight, overwrite = false) ->
    return bb.try(-> true) if !overwrite && actions_store[@_namespace][action]
    actions_store[@_namespace][action] = weight
    bb.try(-> true)

  get_action_weight: (action) ->
    bb.try(=> actions_store[@_namespace][action])


  bootstrap: (stream) ->
    deferred = bb.defer()
    stream = stream.pipe(split(/^/gm))
    count = 0
    stream.on('data', (chunk) => 
      return if chunk == ''
      e = chunk.split(',')
      expires_at = if e[4] != '' then new Date(e[4]) else null
      @add_event(e[0], e[1], e[2], {created_at: new Date(e[3]), expires_at: expires_at})
      count += 1
    )
    stream.on('end', -> deferred.resolve(count))
    stream.on('error', (error) -> deferred.reject(error))
    deferred.promise

  pre_compact: ->
    bb.try(-> true)

  _delete_events: (events) ->
    event_store[@_namespace] = event_store[@_namespace].filter((x) -> x not in events)
    for e in events
      delete person_action_store[@_namespace][e.person][e.action][e.thing]
      delete thing_action_store[@_namespace][e.thing][e.action][e.person]

  delete_events: (person, action, thing) ->
    events = @_find_events(person, action, thing) 
    @_delete_events(events)
    bb.try(=> {deleted: events.length})

  
  compact_people: (limit) ->
    #remove all 
    marked_for_deletion = []
    for person, action_store of person_action_store[@_namespace]
      for action, weight of actions_store[@_namespace]
        events = @_person_history_for_action(person, action)
        if events.length > limit
          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(marked_for_deletion)
    bb.try(-> true)


  compact_things: (limit) ->
    marked_for_deletion = []
    for thing, action_store of thing_action_store[@_namespace]
      for action, weight of actions_store[@_namespace]
        events = @_thing_history_for_action(thing, action)
        if events.length > limit
          
          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(marked_for_deletion)
    bb.try(-> true)

  expire_events: ->
    marked_for_deletion = []
    for e in event_store[@_namespace]
      if e && e.expires_at && e.expires_at < new Date()
        marked_for_deletion.push e

    @_delete_events(marked_for_deletion)
    bb.try(-> true)

  post_compact: ->
    bb.try(-> true)
    
#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return BasicInMemoryESM)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = BasicInMemoryESM;
