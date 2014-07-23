Good Enough Reccomendations (GER) is a collaborative filtering based recomendations engine.
GER is built to be easy to use and integrate into any application.

Read more here [Good Enough Recomendations with GER]

#Quick Start

Create a GER instance by first creating a connection to the database with knex, then creating a Postgres Event Store Mapper (ESM).

```coffeescript
#knex is needed for a database connection
knex = require('knex')(
  {
  client: 'pg', 
  connection: 
    {
      host: '127.0.0.1', 
      user : 'root', 
      password : 'abcdEF123456', 
      database : 'ger'
    }
  }
)

#Postgres Event Store Mapper (ESM) is the mapping from Events to the persistance layer of Postgres.

PsqlESM = require('./lib/psql_esm')
GER = require('ger')

psql_esm = new PsqlESM(knex)

#create the tables if they do not already exist
psql_esm.init_tables()

ger = new GER(psql_esm)
```


#The GER API

The core method of GER is the event:
```coffeescript
ger.event("person", "action", "thing")
```

Each person, action and thing are just strings that are then used to query for recommendations.

GER can be queried to recommend things a "person" might like to "action".

```
ger.recommendations_for_person("person", "action")
```

Or ask what people might "action" a "thing".

```
ger.recommendations_for_thing("thing", "action")
```

GER can be queried for similar people or things.

```
ger.ordered_similar_people("person")
ger.ordered_similar_things("thing")
```

Actions can be assinged weights to increase their importance for GER predicitons.

```
ger.set_action_weight("action", 1)
```
