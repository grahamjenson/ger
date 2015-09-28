
# Good Enough Recommendations (GER)
<img src="./assets/ger300x200.png" align="right" alt="GER logo" />

Providing good recommendations can get greater user engagement and provide an opportunity to add value that would otherwise not exist. The main reason why many applications don't provide recommendations is the difficulty in either implementing a custom engine or using an existing engine.

Good Enough Recommendations (**GER**) is a recommendation engine that is scalable, easily usable and easy to integrate. GER's goal is to generate **good enough** recommendations for your application or product, so that you can provide value quickly and painlessly.

##Quick Start Guide

**Note: functions from GER return a promises**

Install `ger` and `coffee-script` with `npm`:

```bash
npm install ger
```

In your javascript code, first require `ger`:

```javascript
var g = require('ger')
```

Initialize an in memory Event Store Manager (ESM) and create a Good Enough Recommender (GER):

```javascript
var esm = new g.MemESM()
var ger = new g.GER(esm);
```

The next step is to initialize a namespace, e.g. `movies`. *A namespace is a bucket of events that will not interfere with other buckets*.

```javascript
ger.initialize_namespace('movies')
```

Next add events to the namespace. *An event is a triple (person, action, thing)* e.g. `bob` `likes` `xmen`.

```javascript
ger.events([{
  namespace: 'movies',
  person: 'bob',
  action: 'likes',
  thing: 'xmen',
  expires_at: '2020-06-06'
}])
```

An event is used by GER in two ways:

1. to compare two people by looking at their history, e.g. `bob` and `alice` `like` similar movies, so `bob` and `alice` are similar
2. provide recommendations from a persons history, e.g. `bob` `liked` a movie `alice` might like, so we can recommend that movie to `alice`

There are two caveats with using events as recommendations:

1. an action may be negative, e.g. `bob` `dislikes` `xmen` which is **not** a recommendation
2. a recommendation ALWAYS expires, e.g. `bob` `likes` `xmen` occurred 15 years ago, so maybe he wouldn't recommend `xmen` now

So GER has the rule: *If an event has an expiry date it is treated as a recommendation until it expires*.

GER can generate recommendations for a person, e.g. *what would alice like?*

```
ger.recommendations_for_person('movies', 'alice', {actions: {likes: 1}
```

and recommendations for a thing, e.g. *what would a person who likes xmen like?*

```
ger.recommendations_for_thing('movies', 'xmen', {actions: {likes: 1}})
```


Lets put it all together:


```javascript
var g = require('ger')
var esm = new g.MemESM()
var ger = new g.GER(esm);

ger.initialize_namespace('movies')
.then( function() {
  return ger.events([
    {
      namespace: 'movies',
      person: 'bob',
      action: 'likes',
      thing: 'xmen',
      expires_at: '2020-06-06'
    },
    {
      namespace: 'movies',
      person: 'bob',
      action: 'likes',
      thing: 'avengers',
      expires_at: '2020-06-06'
    },
    {
      namespace: 'movies',
      person: 'alice',
      action: 'likes',
      thing: 'xmen',
      expires_at: '2020-06-06'
    },
  ])
})
.then( function() {
  // What things might alice like?
  return ger.recommendations_for_person('movies', 'alice', {actions: {likes: 1}})
})
.then( function(recommendations) {
  console.log("\nRecommendations For 'alice'")
  console.log(JSON.stringify(recommendations,null,2))
})
.then( function() {
  // What things are similar to xmen?
  return ger.recommendations_for_thing('movies', 'xmen', {actions: {likes: 1}})
})
.then( function(recommendations) {
  console.log("\nRecommendations Like 'xmen'")
  console.log(JSON.stringify(recommendations,null,2))
})
```

This will output:

```json
Recommendations For 'alice'
{
  "recommendations": [
    {
      "thing": "xmen",
      "weight": 1.5,
      "last_actioned_at": "2015-07-09T14:33:37+01:00",
      "last_expires_at": "2020-06-06T01:00:00+01:00",
      "people": [
        "alice",
        "bob"
      ]
    },
    {
      "thing": "avengers",
      "weight": 0.5,
      "last_actioned_at": "2015-07-09T14:33:37+01:00",
      "last_expires_at": "2020-06-06T01:00:00+01:00",
      "people": [
        "bob"
      ]
    }
  ],
  "neighbourhood": {
    "bob": 0.5,
    "alice": 1
  },
  "confidence": 0.0007147696406599602
}

Recommendations Like 'xmen'
{
  "recommendations": [
    {
      "thing": "avengers",
      "weight": 0.5,
      "last_actioned_at": "2015-07-09T14:33:37+01:00",
      "last_expires_at": "2020-06-06T01:00:00+01:00",
      "people": [
        "bob"
      ]
    }
  ],
  "neighbourhood": {
    "avengers": 0.5
  },
  "confidence": 0.0007923350883032776
}
```

In the recommendations for `alice`, `xmen` is the highest rated recommendations because alice has `liked` it before, so she probably likes it now. You can filter out recommendations that have been actioned before using the `filter_previous_actions` configuration key described below.

*This code for this example is in the `./examples/basic_recommendations_exmaple.js` script*

## Configuration

GER lets you set some values to customize recommendations generation using a `configuration`. Below is a description of all the configurable keys and their defaults:

| Key                         |   Default
|---                          |---
| `actions`                   |    `{}`
| `minimum_history_required`  |    `0`
| `neighbourhood_search_size` |    `100`
| `similarity_search_size`    |    `100`
| `neighbourhood_size`        |    `25`
| `recommendations_per_neighbour`      |    `10`
| `filter_previous_actions`   |    `[]`
| `event_decay_rate`          |    `1`
| `time_until_expiry`         |    `0`
| `current_datetime`          |    `now()`


2. `actions` is an object where the keys are actions names, and the values are action weights that represent the importance of the action
3. `minimum_history_required` is the minimum amount of events a person has to have to even bother generating recommendations. It is good to stop low confidence recommendations being generated.
4. `neighbourhood_search_size` the amount of events in the past that are used to search for the neighborhood. This value has the highest impact on performance but past a certain point has no (or negative) impact on recommendations.
5. `similarity_search_size` is the amount of events in the history used to calculate the similarity between things or people.
5. `neighbourhood_size` the number of similar people (or things) that are searched for. This value has a significant performance impact, and increasing it past a point will also gain diminishing returns.
6. `recommendations_per_neighbour` the number of recommendations each similar person can offer. This is to stop a situation where a single highly similar person provides all recommendations.
7. `filter_previous_actions` it removes recommendations that the person being recommended already has in their history. For example, if a person has already liked `xmen`, then if `filter_previous_actions` is `["liked"]` they will not be recommended `xmen`.
8. `event_decay_rate` the rate at which event weight will decay over time, `weight * event_decay_rate ^ (- days since event)`
9. `time_until_expiry` is the number (in seconds) from `now()` where recommendations that expire will be removed. For example, recommendations on a website might be valid for minutes, where in a email you might recommendations valid for days.
10. `current_datetime` defines a "simulated" current time that will not use any events that are performed after `current_datetime` when generating recommendations.

For example, generating recommendations with a configuration from GER:

```javascript
ger.recommendations_for_person('movies', 'alice', {
  "actions": {
    "like": 1,
    "watch": 5
  },
  "minimum_history_required": 5,
  "similarity_search_size": 50,
  "neighbourhood_size": 20,
  "recommendations_per_neighbour": 10,
  "filter_previous_actions": ["watch"],
  "event_decay_rate": 1.05,
  "time_until_expiry": 180
})
```

## Technology

GER is implemented in Coffee-Script on top of Node.js ([here](http://www.maori.geek.nz/post/why_should_you_use_coffeescript_instead_of_javascript) are my reasons for using Coffee-Script). The core logic is implemented in an abstractions called an Event Store Manager (**ESM**), this is the persistency and many calculations occur.

Currently there is an in memory ESM and a PostgreSQL ESM. There is also a RethinkDB ESM in the works being implemented by the awesome [linuxlich](https://github.com/thelinuxlich/ger).

## Event Store Manager

If you ask

> Why is GER not available on X?

Where X is some database or store (e.g. Redis, Mongo, Cassandra ...). The way to make it available on these systems is to implement your own ESM for it.

The API for an ESM is:

*Initialization*:

1. `esm = new ESM(options)` where options is used to setup connections and such.
2. `initialize(namespace)` will create a `namespace` for events.
3. `destroy(namespace)` will destroy all resources for ESM in namespace
4. `exists(namespace)` will check if the namespace exists
5. `list_namespaces` returns a list of namespaces
*Events*:

1. `add_events`
2. `add_event`
3. `find_events`
4. `delete_events`

*Thing Recommendations*:

1. `thing_neighbourhood`
1. `calculate_similarities_from_thing`

*Person Recommendations*

1. `person_neighbourhood`
1. `calculate_similarities_from_person`
1. `filter_things_by_previous_actions`
1. `recent_recommendations_by_people`

*Compacting*:

1. pre_compact
2. compact_people
3. compact_things
4. post_compact

## Additional Reading

Posts about (or related to) GER:

1. Demo Movie Recommendations Site: [Yeah, Nah](http://yeahnah.maori.geek.nz/)
1. Overall description and motivation of GER: [Good Enough Recommendations with GER](http://maori.geek.nz/post/good_enough_recomendations_with_ger)
2. How GER works [GER's Anatomy: How to Generate Good Enough Recommendations](http://www.maori.geek.nz/post/how_ger_generates_recommendations_the_anatomy_of_a_recommendations_engine)
2. Testing frameworks being used to test GER: [Testing Javascript with Mocha, Chai, and Sinon](http://www.maori.geek.nz/post/introduction_to_testing_node_js_with_mocha_chai_and_sinon)
4. [Postgres Upsert (Update or Insert) in GER using Knex.js](http://www.maori.geek.nz/post/postgres_upsert_update_or_insert_in_ger_using_knex_js)
5. [List of Recommender Systems](https://github.com/grahamjenson/list_of_recommender_systems)

## Changelog

2015-07-09 - updated readme and fixed basicmem ESM bug.

2015-02-01 - fixed bug with set_namespace and added tests

2015-01-30 - added a few helper methods for namespaces, and removed caches to be truly stateless.

2014-12-30 - added find and delete events methods.

2014-12-22 - added exists to check if namespace is initilaized. also changed some indexes in rethinkdb, and changed some semantics around initialize

2014-12-22 - Added Rethink DB Event Store Manager.

2014-12-9 - Added more explanation to the returned recommendations so they can be reasoned about externally

2014-12-4 - Changed ESM API to be more understandable and also updated README

2014-11-27 - Started returning the last actioned at date with recommendations

2014-11-25 - Added better way of selecting recommendations from similar people.

2014-11-12 - Added better heuristic to select related people. Meaning less related people need to be selected to find good values
