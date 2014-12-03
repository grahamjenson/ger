
<img src="./assets/ger300x200.png" align="right" alt="GER logo" />

Good Enough Recommendations (GER) is a recommendations engine.
GER is built to be easy to use, easy to integrate and easy to understand. Its primary goal is to be the calculator to generate recommendations for your application or product.

Posts about (or related to) GER:

1. Overall description and motivation of GER: [Good Enough Recommendations with GER](http://maori.geek.nz/post/good_enough_recomendations_with_ger)
2. Testing frameworks being used to test GER: [Testing Javascript with Mocha, Chai, and Sinon](http://www.maori.geek.nz/post/introduction_to_testing_node_js_with_mocha_chai_and_sinon)
3. Bootstrap function for dumping data into GER: [Streaming directly into Postgres with Hapi.js and pg-copy-stream](http://www.maori.geek.nz/post/streaming_directly_into_postgres_with_hapi_js_and_pg_copy_stream)
4 [Postgres Upsert (Update or Insert) in GER using Knex.js](http://www.maori.geek.nz/post/postgres_upsert_update_or_insert_in_ger_using_knex_js)

#Quick Start Guide

Install `ger` with `npm`:

```bash
npm install ger
```

require `ger` into your code:

```javascript
var g = require('ger')
var GER = g.GER
```

Create a [knex](http://knexjs.org/) connection to Postgres:

```javascript
var knex = g.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'root', database : 'ger'}})
```

Initialise a Postgres Event Store Mapper (ESM), which is the mapping between GER and the persistence layer:

```javascript
var psql_esm = new g.PsqlESM(knex)
```

Initialize the tables in PostGres:

```
psql_esm.initialize() //create the tables if they don't exist
```

Then create the GER instance by passing the ESM:

```javascript
var ger = new GER(psql_esm);
```

Now you are ready to use GER.

#Overview
Using a recommendations engine in an application can get greater engagement from its users, and add value that it would otherwise not have been able to. The reason why many applications don't use recommendations engines is that there is significant overhead in implementing a custom engine and many off-the-shelf engines have overcomplicated APIs that do not suite an applications development.

This documentation describes **GER** (Good Enough Recommendations), a recommendation engine that is scalable, easily usable and good enough for your application.

#Good Enough Recommendations (GER)

**All functions from GER return a promise.**

A recommendation engine is a secondary consideration to a product; it is not the highest priority on your list right now, but it is probably on your list. GER's core goal is to let developers easily integrate a recommendation engine that works for their product, but is not overly complex to get up and running. As your product grows and becomes successful, GER can be fine tuned to provide more targeted recommendations. Initially though, **it will just work**.

#The GER API

GER is a [collaborative filtering](http://en.wikipedia.org/wiki/Collaborative_filtering) engine using the [Jaccard metric](http://en.wikipedia.org/wiki/Jaccard_index). This means that GER looks at past events of a person, finds similar people, then recommends things that those similar users are doing. Basically, events go into GER and recommendations come out.

## Events
An event is simply a triple: a **person:*String***, an **action:*String*** and a **thing:*String***. For example, **bob** **view** **product_2**. 

```javascript
ger.event("person", "action", "thing");
```


## Recommendations 

To query GER for a list of recommendations you ask what a **person** would like to **action**? For example, to ask GER what would **bob** like to **view**:

```
ger.recommendations_for_person("bob", "view")
```

This will return a list of **thing**s with weights 

## Actions
Each action has a weight (defaulting to 1) which determines how important it is to GER's predictions, e.g. **buying** is more important than **viewing**. The weight of an action can be altered with:

```
ger.action("action", 10)
```



#Development

##Event Store Manager

The API for Initialization

1. `esm = new ESM(namespace, options = {})`
2. `initialize()` will create resources necessary for ESM to function
3. `destroy()` will destroy all resources for ESM

The API for the ESM to generate recommendations is:

1. `get_actions()` returns the actions with weights e.g. {'like': 1}
2. `find_similar_people(person, action, actions, limits...)` returns 
3. `calculate_similarities_from_person(person, people, actions, limits...)`
4. `recently_actioned_things_by_people(people)`
5. `person_history_count`
6. `filter_things_by_previous_actions`

The API for the ESM to insert data is:

1. `add_event` (also `find_event`)
2. `count_events` and `estimate_event_count`
2. `set_action_weight` (also `get_action_weight`)
3. `bootstrap`

The API for the ESM to compact the database is:

1. `pre_compact`
2. `compact_people`
3. `compact_things`
4. `expire_events`
5. `post_compact`

#Changelog
2014-11-27 - Started returning the last actioned at date with recommendations

2014-11-25 - Added better way of selecting recommendations from similar people.

2014-11-12 - Added better heuristic to select related people. Meaning less related people need to be selected to find good values