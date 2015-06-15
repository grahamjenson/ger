bb = require 'bluebird'
_ = require 'underscore'
split = require 'split'

moment = require 'moment'

event_store = {}
person_action_store = {}
thing_action_store = {}

Errors = require './errors'

#This is a simple implementation of an ESM to demonstrate the API and NOT FOR PRODUCTION PURPOSES
class BasicInMemoryESM

  constructor: (options = {}) ->

  initialize: (namespace) ->
    event_store[namespace] ||= []
    person_action_store[namespace] ||= {}
    thing_action_store[namespace] ||= {}
    bb.try(-> )

  destroy: (namespace) ->
    delete event_store[namespace]
    delete person_action_store[namespace]
    delete thing_action_store[namespace]
    bb.try(-> )

  exists: (namespace) ->
    bb.try(=> !!event_store[namespace])


  _person_history_for_action: (namespace, person, action) ->
    return [] if person_action_store[namespace][person] == undefined or person_action_store[namespace][person][action] == undefined
    events = (event for thing, event of person_action_store[namespace][person][action])  
    return _.sortBy(events, (x) -> - x.created_at.getTime())

  _person_history_for_action_after_expiry: (namespace, person, action, expires_after) ->
    (e for e in @_person_history_for_action(namespace, person, action) when moment(e.expires_at).isAfter(expires_after) )
      
  _thing_history_for_action: (namespace, thing, action) ->
    return [] if thing_action_store[namespace][thing] == undefined or thing_action_store[namespace][thing][action] == undefined
    events = (event for person, event of thing_action_store[namespace][thing][action])  
    return _.sortBy(events, (x) -> - x.created_at.getTime())

  _find_similar_people_for_action: (namespace, person, action_to_search, person_history_limit, expires_after) ->
    #find things the person has actioned
    person_history = @_person_history_for_action(namespace, person, action_to_search)
    things = (e.thing for e in person_history)
    #find people who have also actioned that thing
    people = []
    for t in things
      thing_history = @_thing_history_for_action(namespace, t, action_to_search)
      people = people.concat (e.person for e in thing_history)

    people = _.uniq(people)
    people

  find_similar_people: (namespace, person, actions, options = {}) ->
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      similar_people_limit: 100
      history_search_size: 500
      expires_after: new Date()
    )

    people = []
    for action_to_search in actions
      people = people.concat @_find_similar_people_for_action(namespace, person, action_to_search, options.history_search_size, options.expires_after)
    people = people.filter((p) -> p != person)
    
    #filter people who have not got an event with current 
    people_to_return = []
    for p in people
      for action_to_search in actions
        list = @_person_history_for_action_after_expiry(namespace, p, action_to_search, options.expires_after)
      
        if list.length > 0
          people_to_return.push p

    return bb.try(-> _.uniq(people_to_return)[...options.similar_people_limit])

  _recent_jaccard_distance: (namespace, p1, p2, action, days, now) ->
    recent_date = moment(now).subtract(days, 'days').toDate()

    p1_things = @_person_history_for_action(namespace, p1,action).filter((e) -> e.created_at > recent_date).map((e) -> e.thing)
    p2_things = @_person_history_for_action(namespace, p2,action).filter((e) -> e.created_at > recent_date).map((e) -> e.thing)

    jaccard = (_.intersection(p1_things, p2_things).length)/(_.union(p1_things, p2_things).length)
    jaccard = 0 if isNaN(jaccard)
    return jaccard

  _jaccard_distance: (namespace, p1, p2, action) ->
    p1_things = @_person_history_for_action(namespace, p1,action).map((e) -> e.thing)
    p2_things = @_person_history_for_action(namespace, p2,action).map((e) -> e.thing)
    jaccard = (_.intersection(p1_things, p2_things).length)/(_.union(p1_things, p2_things).length)
    jaccard = 0 if isNaN(jaccard)
    return jaccard

  calculate_similarities_from_person: (namespace, person, people, actions, person_history_limit=100, recent_event_days= 14, now = new Date()) ->
    return bb.try(-> {}) if !actions or actions.length == 0 or people.length == 0
    similarities = {}
    for p in people
      similarities[p] = {}
      for action in actions
        jaccard = @_jaccard_distance(namespace, person, p, action)
        recent_jaccard = @_recent_jaccard_distance(namespace, person, p, action, recent_event_days, now)
        similarities[p][action] = ((recent_jaccard * 4) + (jaccard * 1))/5.0

    return bb.try(-> similarities)

  recently_actioned_things_by_people: (namespace, actions, people, related_things_limit, expires_after = new Date()) ->
    return bb.try(->[]) if people.length == 0

    group_by_person_thing = {}
    for person in people
      group_by_person_thing[person] = {}
      for action in actions
        for event in @_person_history_for_action_after_expiry(namespace, person, action, expires_after)

          group_by_person_thing[person][event.thing] = {} if not group_by_person_thing[person][event.thing]
          group_by_person_thing[person][event.thing] = {
            thing: event.thing
            last_actioned_at: Math.max(event.created_at.getTime(), group_by_person_thing[person][event.thing].last_actioned_at||0)
            last_expires_at: Math.max(event.expires_at.getTime(), group_by_person_thing[person][event.thing].last_expires_at||0)
          }

    things = {}
    for person in people
      things[person] = []
      for thing, list of group_by_person_thing[person]
        things[person] = (things[person].concat list)[...related_things_limit]

    bb.try(-> things)

  person_history_count: (namespace, person) ->
    things = []
    for action, thing_events of person_action_store[namespace][person]
      things = things.concat(Object.keys(thing_events))

    return bb.try(-> _.uniq(things).length)


  _filter_things_by_previous_action: (namespace, person, things, action) ->
    things.filter((t) => !person_action_store[namespace][person] or !person_action_store[namespace][person][action] or !person_action_store[namespace][person][action][t])

  filter_things_by_previous_actions: (namespace, person, things, actions) ->
    return bb.try(-> things) if !actions or actions.length == 0 or things.length == 0
    filtered_things = things
    for action in actions
      filtered_things = _.intersection(filtered_things, @_filter_things_by_previous_action(namespace, person, things, action))
    return bb.try(-> filtered_things)

  add_events: (events) ->
    promises = []
    for e in events
      promises.push @add_event(e.namespace, e.person, e.action, e.thing, {created_at: e.created_at, expires_at: e.expires_at})
    bb.all(promises)

  add_event: (namespace, person, action, thing, dates = {}) ->
    if !event_store[namespace]
      return bb.try( -> throw new Errors.NamespaceDoestNotExist())

    created_at = dates.created_at || new Date()
    expires_at = if dates.expires_at then new Date(dates.expires_at) else null
    found_event = @_find_event(namespace, person, action, thing)

    if found_event
      found_event.created_at = if created_at > found_event.created_at then created_at else found_event.created_at
      found_event.expires_at = if expires_at && expires_at > found_event.expires_at then expires_at else found_event.expires_at
    else
      e = {person: person, action: action, thing: thing, created_at: created_at, expires_at: expires_at}
      event_store[namespace].push e

      person_action_store[namespace][person] ||= {}
      person_action_store[namespace][person][action] ||= {}
      person_action_store[namespace][person][action][thing] = e

      thing_action_store[namespace][thing] ||= {}
      thing_action_store[namespace][thing][action] ||= {}
      thing_action_store[namespace][thing][action][person] = e

    bb.try(-> true)

  count_events: (namespace) ->
    return bb.try(=>  event_store[namespace].length)

  estimate_event_count: (namespace) ->
    return bb.try(=> event_store[namespace].length)

  _find_event: (namespace, person, action, thing) ->
    return null if not person_action_store[namespace][person]
    return null if not person_action_store[namespace][person][action]
    return null if not person_action_store[namespace][person][action][thing]
    return person_action_store[namespace][person][action][thing]

  _find_events: (namespace, person, action, thing) ->
    #returns all events fitting the above description
    events = []
    for e in event_store[namespace]
      add = true

      if person
        if _.isArray(person)
          add = false if not _.contains(person, e.person)
        else
          add = false if person != e.person

      if action
        if _.isArray(action)
          add = false if not _.contains(action, e.action)
        else
          add = false if action != e.action

      if thing
        if _.isArray(thing)
          add = false if not _.contains(thing, e.thing)
        else
          add = false if thing != e.thing

      events.push e if add
    events = _.sortBy(events, (x) -> - x.created_at.getTime())

    return events

  find_events: (namespace, person, action, thing, options = {}) ->
    options = _.defaults(options, {size: 50, page: 0})
    size = options.size
    page = options.page

    events = @_find_events(namespace, person, action, thing)
    events = events[size*page ... size*(page+1)]
    return bb.try(=> events)



  bootstrap: (namespace, stream) ->
    deferred = bb.defer()
    stream = stream.pipe(split(/^/gm))
    count = 0
    stream.on('data', (chunk) => 
      return if chunk == ''
      e = chunk.split(',')
      expires_at = if e[4] != '' then new Date(e[4]) else null
      @add_event(namespace, e[0], e[1], e[2], {created_at: new Date(e[3]), expires_at: expires_at})
      count += 1
    )
    stream.on('end', -> deferred.resolve(count))
    stream.on('error', (error) -> deferred.reject(error))
    deferred.promise

  pre_compact: ->
    bb.try(-> true)

  _delete_events: (namespace, events) ->
    event_store[namespace] = event_store[namespace].filter((x) -> x not in events)
    for e in events
      delete person_action_store[namespace][e.person][e.action][e.thing]
      delete thing_action_store[namespace][e.thing][e.action][e.person]

  delete_events: (namespace, person, action, thing) ->
    events = @_find_events(namespace, person, action, thing) 
    @_delete_events(namespace, events)
    bb.try(=> {deleted: events.length})

  
  compact_people: (namespace, limit, actions) ->
    #remove all 
    marked_for_deletion = []
    for person, action_store of person_action_store[namespace]
      for action in actions
        events = @_person_history_for_action(namespace, person, action)
        if events.length > limit
          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(namespace, marked_for_deletion)
    bb.try(-> true)


  compact_things: (namespace, limit, actions) ->
    marked_for_deletion = []
    for thing, action_store of thing_action_store[namespace]
      for action in actions
        events = @_thing_history_for_action(namespace, thing, action)
        if events.length > limit
          
          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(namespace, marked_for_deletion)
    bb.try(-> true)

  post_compact: ->
    bb.try(-> true)
    
#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return BasicInMemoryESM)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = BasicInMemoryESM;
