bb = require 'bluebird'
_ = require 'lodash'

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

  list_namespaces: ->
    bb.try(-> Object.keys(event_store))
  ###########################
  ####  NEIGHBOURHOOD  ######
  ###########################

  thing_neighbourhood: (namespace, thing, actions, options = {}) ->
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      neighbourhood_size: 100
      neighbourhood_search_size: 500
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.actions = actions
    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    one_degree_away = @_one_degree_away(namespace, 'thing', 'person', thing, _.clone(options))

    one_degree_away = one_degree_away.filter( (x) -> x.thing != thing && !!x.last_expires_at && !moment(x.last_expires_at).isBefore(options.expires_after))
    one_degree_away.map( (x) -> x.people = _.uniq(x.person); delete x.person)
    one_degree_away = _.sortBy(one_degree_away, (x) -> - x.people.length)
    bb.try(-> one_degree_away[...options.neighbourhood_size])

  person_neighbourhood: (namespace, person, actions, options = {}) ->
    return bb.try(-> []) if !actions or actions.length == 0

    options = _.defaults(options,
      neighbourhood_size: 100
      neighbourhood_search_size: 500
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.actions = actions
    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format()

    one_degree_away = @_one_degree_away(namespace, 'person', 'thing', person, _.clone(options))

    query_hash = _.clone(options)
    query_hash.people = one_degree_away.map((x) -> x.person)
    unexpired_events = (x.person for x in @_find_events(namespace, query_hash) when person != x.person)

    bb.try(-> _.uniq(unexpired_events)[...options.neighbourhood_size])



  _one_degree_away: (namespace, column1, column2, value, options) ->
    search_hash = {
      current_datetime: options.current_datetime
      actions: options.actions
      size: options.neighbourhood_search_size
    }

    search_hash_1 = _.clone(search_hash)
    search_hash_1[column1] = value

    ret = {}
    for x in @_find_events(namespace, search_hash_1)
      search_hash_2 = _.clone(search_hash)
      search_hash_2[column2] = x[column2]
      for y in @_find_events(namespace, search_hash_2)
        if ret[y[column1]] == undefined
          ret[y[column1]] = {
            "#{column1}": y[column1]
            "#{column2}": [y[column2]]
            last_actioned_at: y.created_at
            last_expires_at: y.expires_at
          }
        else
          ret[y[column1]][column2].push(y[column2])
          ret[y[column1]].last_actioned_at = moment.max(moment(ret[y[column1]].last_actioned_at), moment(y.created_at)).toDate()

          if ret[y[column1]].last_expires_at == null
            ret[y[column1]].last_expires_at = y.expires_at
          else if y.expires_at != null
            ret[y[column1]].last_expires_at = moment.max(moment(ret[y[column1]].last_expires_at), moment(y.expires_at)).toDate()

    _.values(ret)

  ##################################
  ####  END OF NEIGHBOURHOOD  ######
  ##################################

  _cosine_distance: (namespace, column1, column2, v1, v2, actions, now, limit, event_decay_rate) ->

    search1 = {current_datetime: now}
    search2 = {current_datetime: now}
    search1[column1] = v1
    search2[column1] = v2
    search1.actions = Object.keys(actions)
    search2.actions = Object.keys(actions)

    p1_values = {}
    for e in @_find_events(namespace, search1)[...limit]
      weight = actions[e.action]
      days = Math.round(moment.duration(moment(now).diff(e.created_at)).asDays())
      n_weight = weight * Math.pow(event_decay_rate,-days)
      p1_values[e[column2]] = n_weight

    p2_values = {}
    for e in @_find_events(namespace, search2)[...limit]
      weight = actions[e.action]
      days = Math.round(moment.duration(moment(now).diff(e.created_at)).asDays())
      n_weight = weight * Math.pow(event_decay_rate,-days)
      p2_values[e[column2]] = n_weight

    numerator = 0
    for value, weight of p1_values
      if p2_values[value]
        numerator += weight * p2_values[value]

    denominator_1 = 0
    for value, weight of p1_values
      denominator_1 += Math.pow(weight,2)

    denominator_2 = 0
    for value, weight of p2_values
      denominator_2 += Math.pow(weight,2)

    cosinse_similarity = numerator/(Math.sqrt(denominator_1)*Math.sqrt(denominator_2))

    return cosinse_similarity

  _similarities: (namespace, column1, column2, value, values, actions, options={}) ->
    return bb.try(-> {}) if values.length == 0

    options = _.defaults(options,
      similarity_search_size: 500
      current_datetime: new Date()
      event_decay_rate: 1
    )

    similarities = {}
    for v in values
      similarities[v] =  @_cosine_distance(namespace, column1, column2, value, v, actions, options.current_datetime, options.similarity_search_size, options.event_decay_rate)
      similarities[v] = similarities[v] || 0

    return bb.try(-> similarities)

  calculate_similarities_from_person: (namespace, person, people, actions, options={}) ->
    @_similarities(namespace, 'person', 'thing', person, people, actions, options)

  calculate_similarities_from_thing: (namespace, person, people, actions, options={}) ->
    @_similarities(namespace, 'thing', 'person', person, people, actions, options)



  _recent_events: (namespace, column1, actions, values, options = {}) ->
    return bb.try(->[]) if values.length == 0 || actions.length == 0

    options = _.defaults(options,
      recommendations_per_neighbour: 10
      time_until_expiry: 0
      current_datetime: new Date()
    )
    options.actions = actions


    all_events = []
    for v in values
      query_hash = {actions: actions}
      query_hash[column1] = v

      events = @_find_events(namespace, _.extend(query_hash, options))[...options.recommendations_per_neighbour]
      all_events = all_events.concat events

    group_by_person_thing = {}

    for event in all_events
      group_by_person_thing[event.person] = {} if not group_by_person_thing[event.person]
      group_by_person_thing[event.person][event.thing] = {} if not group_by_person_thing[event.person][event.thing]

      last_actioned_at = group_by_person_thing[event.person][event.thing].last_actioned_at || event.created_at
      last_actioned_at = moment.max(moment(last_actioned_at), moment(event.created_at)).toDate()

      last_expires_at = group_by_person_thing[event.person][event.thing].last_expires_at || event.expires_at
      last_expires_at = moment.max(moment(last_expires_at), moment(event.expires_at)).toDate()


      group_by_person_thing[event.person][event.thing] = {
        person: event.person
        thing: event.thing
        last_actioned_at: last_actioned_at
        last_expires_at: last_expires_at
      }

    grouped_events = []
    for person, thing_events of group_by_person_thing
      for thing, event of thing_events
        grouped_events = grouped_events.concat event

    grouped_events = _.sortBy(grouped_events, (x) -> - x.last_actioned_at.getTime())
    bb.try(-> grouped_events)

  recent_recommendations_by_people: (namespace, actions, people, options) ->
    @_recent_events(namespace, 'person', actions, people, options)

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

    created_at = moment(dates.created_at || new Date()).toDate()
    expires_at = if dates.expires_at then moment(new Date(dates.expires_at)).toDate() else null
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

  _filter_event: (e, options) ->
    return false if !e

    add = true
    if moment(options.current_datetime).isBefore(e.created_at)
      add = false

    if options.expires_after && (!e.expires_at || moment(e.expires_at).isBefore(options.expires_after))
      add = false

    if options.people
      add = false if not _.contains(options.people, e.person)

    if options.person
      add = false if options.person != e.person


    if options.actions
      add = false if not _.contains(options.actions, e.action)

    if options.action
      add = false if options.action != e.action

    if options.things
      add = false if not _.contains(options.things, e.thing)

    if options.thing
      add = false if options.thing != e.thing

    add

  _find_events: (namespace, options = {}) ->
    options = _.defaults(options,
      size: 50
      page: 0
      current_datetime: new Date()
    )

    options.expires_after = moment(options.current_datetime).add(options.time_until_expiry, 'seconds').format() if options.time_until_expiry != undefined

    #returns all events fitting the above description
    events = []

    if options.person and options.action and options.thing
      e = person_action_store[namespace]?[options.person]?[options.action]?[options.thing]
      events = [e]
    else if options.person and options.action
      events = (e for t, e of person_action_store[namespace]?[options.person]?[options.action])
    else if options.thing and options.action
      events = (e for t, e of thing_action_store[namespace]?[options.thing]?[options.action])
    else if options.person
      events = (e for t,e of ats for at, ats of person_action_store[namespace]?[options.person])
    else if options.thing
      events = (e for t,e of ats for at, ats of thing_action_store[namespace]?[options.thing])
    else if options.people
      events = (e for t,e of ats for at, ats of person_action_store[namespace]?[thth] for thth in options.people)
    else if options.things
      events = (e for t,e of ats for at, ats of thing_action_store[namespace]?[thth] for thth in options.things)
    else
      events = (e for e in event_store[namespace])

    events = _.flatten(events, true)
    events = (e for e in events when @_filter_event(e, options))
    events = _.sortBy(events, (x) -> - x.created_at.getTime())

    events = events[options.size*options.page ... options.size*(options.page+1)]
    return events

  find_events: (namespace, options = {}) ->
    return bb.try(=> @_find_events(namespace, options))


  pre_compact: ->
    bb.try(-> true)

  _delete_events: (namespace, events) ->
    event_store[namespace] = event_store[namespace].filter((x) -> x not in events)
    for e in events
      delete person_action_store[namespace][e.person][e.action][e.thing]
      delete thing_action_store[namespace][e.thing][e.action][e.person]

  delete_events: (namespace, options = {}) ->
    events = @_find_events(namespace, person: options.person, action: options.action, thing: options.thing)
    @_delete_events(namespace, events)
    bb.try(=> {deleted: events.length})


  compact_people: (namespace, limit, actions) ->
    #remove all
    marked_for_deletion = []
    for person, action_store of person_action_store[namespace]
      for action in actions
        events = @_find_events(namespace, person: person, action: action)
        if events.length > limit
          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(namespace, marked_for_deletion)
    bb.try(-> true)


  compact_things: (namespace, limit, actions) ->
    marked_for_deletion = []
    for thing, action_store of thing_action_store[namespace]
      for action in actions
        events = @_find_events(namespace, thing: thing, action: action)
        if events.length > limit

          marked_for_deletion = marked_for_deletion.concat events[limit..-1]

    @_delete_events(namespace, marked_for_deletion)
    bb.try(-> true)

  post_compact: ->
    bb.try(-> true)


module.exports = BasicInMemoryESM;
