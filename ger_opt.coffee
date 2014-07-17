#cat aug_feb_vr.csv| grep 2013-08 | awk -F, '{if($3 && $4 && $4 != "undefined") print $3","$5","$4}' > aug_events.csv


#single line ger
#ger = new (require('./ger').GER)(new (require('./lib/psql_esm'))(require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_opt'}})))


#This Script takes a csv of PERSON,ACTION,THING ordered by time and attempts to optimise the 
MemoryESM = require('./lib/memory_esm')
PsqlESM = require('./lib/psql_esm')
GER = require('./ger').GER
q = require 'q'

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_opt'}})

FS = require("q-io/fs");

[..., filename] = process.argv

#take the first 2 thirds of the file

#add them to ger with each action being equal to 1 and 

#INITIALIZE OPT DB
events_from_csv_to_ger = (ger) ->
  FS.read(filename, "r")
  .then((lines) ->
    console.log "READING LINES"
    events = []
    actions = {}
    lines = lines.split('\n')[...-1]
    console.log "SPLIT LINES"
    lines
  ).then( (lines) ->
    p = q.fcall( -> )
    i = 0
    for line in lines
      do (line) ->
        i = i + 1
        #console.log line
        #turn line to promise
        
        [person, action, thing] = line.split(',')
        p = p.then( -> ger.event(person, action, thing))

        #output
        if i % 1000 == 0
          process.stderr.write(":") 
          p = p.then(-> process.stderr.write("."))
    p
  )

init_new_ger = ->
  #q.fcall(-> new GER(new MemoryESM()))
  psql_esm = new PsqlESM(knex)
  q.fcall(-> psql_esm.drop_tables())
  .then( -> psql_esm.init_tables())
  .then( -> new GER(psql_esm))

init_opt_db = ->
  console.log "init DB"
  init_new_ger()
  .then( (ger) ->
    console.log "Loading Events..."
    events_from_csv_to_ger(ger)
  )

#init_opt_db().then(-> console.log "done").fail(console.log).fin(-> knex.destroy())


#setup the weights

#select the people, and calculate accuracy



