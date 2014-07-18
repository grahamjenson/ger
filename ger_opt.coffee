#This script has been written to take a csv of person,action,events and allow for experimentation
#to find good settings for your GER
#it takes this file and splits it into two parts, one part is added to GER and the other part is used
# for testing gers prediction accuracy
#It is still very much in the todo category

exec = require('child_process').exec
MemoryESM = require('./lib/memory_esm')
PsqlESM = require('./lib/psql_esm')
GER = require('./ger').GER
q = require 'q'

#single line ger
#ger = new (require('./ger').GER)(new (require('./lib/psql_esm'))(require('knex')({client: 'pg', connection: {host: '127.0.0.1', person : 'root', password : 'abcdEF123456', database : 'ger_opt'}})))


Utils =
  flatten: (arr) ->
    arr.reduce ((xs, el) ->
      if Array.isArray el
        xs.concat Utils.flatten el
      else
        xs.concat [el]), []

  unique : (arr)->
    output = {}
    output[arr[key]] = arr[key] for key in [0...arr.length]
    value for key, value of output

  shuffle : (a) ->
    i = a.length
    while --i > 0
      j = ~~(Math.random() * (i + 1)) # ~~ is a common optimization for Math.floor
      t = a[j]
      a[j] = a[i]
      a[i] = t
    a

execute = (command) ->
  deferred = q.defer()
  exec(command, {maxBuffer: 10000*1024}, (error, stdout, stderr) ->
    if error
      deferred.reject(error)
    else
      deferred.resolve(stdout.split('\n').filter (u) -> u isnt '')
  )
  return deferred.promise



knex = -> require('knex')({client: 'pg', connection: {host: '127.0.0.1', person : 'root', password : 'abcdEF123456', database : 'ger_opt'}})

FS = require("q-io/fs");

[..., filename] = process.argv


events_from_csv_to_ger = (ger) ->
  command = "head -n #{split_file_at_line} #{filename}"
  execute(command)
  .then( (lines) ->
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
  psql_esm = new PsqlESM(knex())
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




get_people_who_have_n_actions = (n) ->
  command = "head -n #{split_file_at_line} #{filename} | awk -F, '{print $1}' | sort | uniq -c | awk -v limit=#{n} '$1 > limit{print $2}'"
  execute(command)

get_known_things = ->
  command = "head -n #{split_file_at_line} #{filename} | awk -F, '{print $3}' | sort | uniq"
  execute(command)

filter_must_contain_thing = (person_things) ->
  get_known_things()
  .then( (things) ->
    person_things.filter (ui) -> ui[1] in things
  )
  
get_person_things_who_actioned = ->
  command = "tail -n+#{split_file_at_line} #{filename} | grep '#{action}' | sort | uniq | awk -F, '{print $1,$3}'"
  execute(command)
  .then((lines) ->
    (line.split(' ') for line in lines)
  )

filter_person_things_for_people_who_actioned_n_times = (person_things, n) =>
  get_people_who_have_n_actions(n)
  .then( (people) ->
    person_things.filter (ui) -> ui[0] in people
  )


extract_person_things = ->
  get_person_things_who_actioned()
  .then( (person_things) -> filter_must_contain_thing(person_things))

predict = (person, actually_actioned_things) ->
  ger = new GER(new PsqlESM(knex()))
  ger.recommendations_for_person(person, action)
  .then( (recs) ->
    predictions = (i.thing for i in recs)
    real = (predictions.indexOf ri for ri in actually_actioned_things)
    [person, real]
  )

calculate_predictions = (person_things) ->
  q(person_things)
  .then( (person_things) -> filter_person_things_for_people_who_actioned_n_times(person_things, 100))
  .then( (person_things) -> 
    people = (ui[0] for ui in person_things)
    people = Utils.unique(people)
    #people = Utils.shuffle(people)
    people = people[..20]
    promises = []
    for person in people[..20]
      do (person) ->
        things = person_things.filter (ui) -> ui[0] == person
        things = (thing[1] for thing in things)
        promises.push (previous) -> predict(person, things).then((newl) -> 
          previous.push newl
          previous
        )


    result = q([])
    promises.forEach((f) ->
      result = result.then(f)
    )
    result
  )


action = "view"
split_file_at_line = 10

extract_person_things()
.then( (person_things) -> calculate_predictions(person_things))
.then((j) -> console.log j).fail(console.log)


#setup the weights

#select the people, and calculate accuracy



