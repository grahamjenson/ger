Good Enough Recommendations (GER) is a collaborative filtering based recommendations engine.
GER is built to be easy to use and integrate into any application.

Read more here [Good Enough Recommendations with GER](http://maori.geek.nz/post/good_enough_recomendations_with_ger)

#Quick Start Guide

Install GER

```bash
npm install ger
```

First create a database connection with knex:

```javascript
var g = require('../ger')
var GER = g.GER
```

Need to create a [knex](http://knexjs.org/) connection:

```javascript
var knex = g.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'root', database : 'ger'}})
```

Then create a Postgres Event Store Mapper (ESM), which is the mapping between GER and the persistence layer:

```javascript
var psql_esm = new g.PsqlESM(knex)

psql_esm.init_tables() //create the tables if they don't exist
```

Then create the GER instance by passing the ESM

```javascript
var ger = new GER(psql_esm);
```

#The GER API

There are four concepts for GER

1. person:String 
2. thing:String
3. action:String which has a weight:Integer (defaults to 1)

**All functions from GER return a promise.**

To add an event to GER use:

```javascript
ger.event("person", "action", "thing");
```

An actions weight can be changed, the higher the weight the more important it is for GER predictions.

```
ger.set_action_weight("action", 10)
```

GER can be queried to recommend things a "person" might like to "action":

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


