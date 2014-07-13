#This Script takes a csv of PERSON,ACTION,THING ordered by time and attempts to optimise the 
MemoryESM = require('./lib/memory_esm')
PsqlESM = require('./lib/psql_esm')
GER = require('./ger').GER
q = require 'q'

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})

FS = require("q-io/fs");

[..., filename] = process.argv

#take the first 2 thirds of the file

#add them to ger with each action being equal to 1 and 

read_events_from_csv= ->
  console.log "asd"
  FS.read(filename, "r")
  .then((lines) ->
    events = []
    actions = {}
    lines.split('\n')[...-1]
    .map(
      (line) -> 
        [person, action, thing] = line.split(',')
        events.push {person: person, action: action, thing: thing}
        actions[action] = 1
    )
    return [events, Object.keys(actions)]
  )

init_new_ger = ->
  q.fcall(-> new GER(new MemoryESM()))
  # psql_esm = new PsqlESM(knex)
  # q.fcall(-> psql_esm.drop_tables())
  # .then( -> psql_esm.init_tables())
  # .then( -> new GER(psql_esm))

optimise = ->
  q.all([read_events_from_csv(), init_new_ger()])
  .spread( (csv, ger) ->
    [events, actions] = csv
    console.log events, actions
    p = []
    for e in events
      console.log e
      p.push ger.event(e.person, e.action, e.thing)
    q.all(p)
  )

optimise().then(-> console.log "done").fail(console.log)



split_train_and_test_sets = (events) ->
  diff_len = Math.floor( events.length * (2/3) )
  return [events[...diff_len], events[diff_len..-1]]


add_test_set = (ger, events) ->


calculate_configuration = ->
  #get actions
  #

find_efficiency_of_configuration: (configuration) ->


optimise_ger_configuration = ->
  read_events_from_csv()
  .then( (events, actions) ->
    q.all([init_new_ger(), events, actions])
  )
  .spread( (ger, events, actions) ->
    p = []
    for action in actions
      p.push ger.set_action_weight(action, 1)
    all_actions = q.all p
    q.all([ger, events, actions, all_actions])
  )
  .spread( (ger, events, actions) ->
    p = []
    for e in events
      p.push ger.add_event(e.person, e.action, e.thing)
    q.all([ger, events, actions, all_actions])
  )
  .spread( (ger, events, actions) ->

  )


