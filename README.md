Good Enough Reccomendations (GER) is a simple recomendations engine that uses collaborative filtering.
GER is built to be a very fast, scalable calculator that can be built upon and wrapped to add specific features that you may need.

#Init

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

#Postgres Event Store Mapper (ESM) is the mapping from 
PsqlESM = require('./lib/psql_esm')
GER = require('ger')

psql_esm = new PsqlESM(knex)

#create the tables if they do not already exist
psql_esm.init_database_tables()

ger = new GER(psql_esm)
```


#The GER API

The core method of GER is the event:
```coffeescript
ger.event("person", "action", "thing")
```

Each person, action and thing are just strings that are then used to query for recommendations.

ger can be queried to recommend things a "person" might like to "action", e.g.

```
ger.recommendations_for_person("person", "action")
```

Or ask what people might "action" a "thing": 

```
ger.recommendations_for_thing("thing", "action")
```

Ger can be queried for similar people or things

```
ger.ordered_similar_people("person")
ger.ordered_similar_things("thing")
```

Particular actions can be weighted so as to increase their importance in the similarity

```
ger.set_action_weight("action", 1)
```