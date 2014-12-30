
<img src="./assets/ger300x200.png" align="right" alt="GER logo" />

Providing good recommendations can get greater user engagement and provide an opportunity to add value that would otherwise not exist. The main reason why many applications don't provide recommendations is the perceived difficulty in either implementing a custom engine or using an off-the-shelf engine.

Good Enough Recommendations (**GER**) is an attempt to reduce this difficulty by providing a recommendation engine that is scalable, easily usable and easy to integrate. GER's primary goal is to generate **good enough** recommendations for your application or product.

Posts about (or related to) GER:

1. Demo Movie Recommendations Site: [Yeah, Nah](http://yeahnah.maori.geek.nz/)
1. Overall description and motivation of GER: [Good Enough Recommendations with GER](http://maori.geek.nz/post/good_enough_recomendations_with_ger)
2. How GER works [GER's Anatomy: How to Generate Good Enough Recommendations](http://www.maori.geek.nz/post/how_ger_generates_recommendations_the_anatomy_of_a_recommendations_engine)
2. Testing frameworks being used to test GER: [Testing Javascript with Mocha, Chai, and Sinon](http://www.maori.geek.nz/post/introduction_to_testing_node_js_with_mocha_chai_and_sinon)
3. Bootstrap function for dumping data into GER: [Streaming directly into Postgres with Hapi.js and pg-copy-stream](http://www.maori.geek.nz/post/streaming_directly_into_postgres_with_hapi_js_and_pg_copy_stream)
4. [Postgres Upsert (Update or Insert) in GER using Knex.js](http://www.maori.geek.nz/post/postgres_upsert_update_or_insert_in_ger_using_knex_js)

#Quick Start Guide

**All functions from GER return a promise.**

Install `ger` with `npm`:

```bash
npm install ger
```

require `ger`:

```javascript
var g = require('ger')
var GER = g.GER
```

Initialize an in memory Event Store Manager (ESM):

```javascript
var esm = new g.MemESM()
esm.initialize()
```

Then create the GER instance by passing the ESM:

```javascript
var ger = new GER(esm);
```

Using the promises library [bluebird](https://www.npmjs.org/package/bluebird) (`bb`) we can add some events and get some recommendations:

```javascript
bb.all([
 ger.action('view', 1),
 ger.action('buy', 10),

 ger.event('p1','view','a'), 
 ger.event('p2','view','a'),
 ger.event('p2','buy','a')
])
.then( function() {
 // What should 'p1' 'buy'?
 return ger.recommendations_for_person('p1', 'buy') 
})
.then( function(recommendations) {
  // {recommendations: [{thing: 'a', weight: '.75'}]}
})
```


#The GER Model

*I am sorry for the formality, but formal models are the easiest way to remove ambiguity and describe precisely what is going on.*

The core sets of GER are:

1. `P` people
2. `T` things
3. `A` actions

Events are in the set that is the Cartesian product of these, i.e. `P × A × T`. For example, when `bob` `like`s the `hobbit` movie, this is represented with the event `<bob, like, hobbit>`.

The history of any given person is all the `thing`'s they have `action`ed in the form `<action,thing>`, i.e. `A × T`. The function `H` takes a person and returns their history. For example the history for `bob` after he `like`d the `hobbit` would be `H(bob) = {<like, hobbit>}`. 

The [Jaccard similarityy](http://en.wikipedia.org/wiki/Jaccard_index) metric, defined as the function `J`, is used to calculate the similarity between people using their histories. That is, the similarity between two people `p1`, `p2` is the Jaccard metric between their two histories `J(p1,p2) = (|H(p1) INTERSECTION H(p2)| / |H(p1) UNION H(p2)|)`. 

For example, given that `bob` `like`d the `hobbit` and `hate`d the `x-men`, where `alice` only `hate`d the `x-men`. 

1. `H(alice) = {<hate, x-men>}`
2. `H(bob) = {<like, hobbit>, <hate, x-men>}`
3. `H(bob) INTERSECTION H(alice) = {<hate, x-men>}` with cardinality `1`
4. `H(bob) UNION H(alice) = {<like, hobbit>, <hate, x-men>}` with cardinality `2`
5. The similarity between `bob` and `alice` is therefore `J(bob,alice) = 1/2`

Jaccard similarity is a proper [metric](http://en.wikipedia.org/wiki/Metric_(mathematics)), so it is comes with many useful properties like *symmetry* where `J(bob, alice) = J(alice,bob)`.

It is also useful to define *similarity*:

1. Two people are said to be **similar** if the have a non-zero Jaccard similarity

### Recommendations

Recommendations are a set of weighted `thing`s which are calculated for a person `p` and action `a` using the function `R(p,a)`. The weight of a thing `t` is the sum of the similarities between the person `p` and all people who have `<a, t>` in their history. One additional constraint on `R` is that it only returns non-zero weighted recommendations.

For Example, given that:

1. `bob` `like`s the `x-men` but `hate`s `harry potter`.
2. `alice` `hate`s `harry potter`, and `like`s the `x-men` and `avengers`
3. `carl` `like`s the `x-men`, the `avengers` and `batman`
 
What should be movie recommendations should `bob` `like`, i.e. `R(bob,like)`? We can calculate that:

1. `J(bob,bob) = 1`
1. `J(bob,alice) = 2/3`
2. `J(bob,carl) = 1/4`

`bob` has three potential recommendations to `like`: `x-men`, `avengers` and `batman`. For each of these we can calculate the weight that `bob` will `like` them:

1. `x-men` is `J(bob,bob) + J(bob,alice) + J(bob,carl) = 1.92`
2. `avengers` is `J(bob,alice) + J(bob,carl) = 0.92`
3. `batman` is `J(bob,carl) = 0.25`

Therefore, the recommendations for `bob` to `like` are `R(bob,like) = {<x-men, 1.92>, <avengers, 0.92>, <batman, 0.25>}`. Even though `bob` has seen `x-men` it has been included in the recommendations because he does `like` it. This would make sense if the recommendations were for something that could be consumed multiple times, like food or music.

#Practical Changes to the Model

The above model is simple and wouldn't be able to deal with some of the real world requirements and limitations. Therefore, some additional features and required limitations to the model to make it practical have been applied. 

## Additional Features

In the simple model each action is treated equally when measuring a persons similarity to another; this is not the case in reality. If two people `like`d the same thing they may be more similar than if they `hate`d the same thing. By weighting each action, and finding the Jaccard similarity **per-action** then combining the results with respect to the action's weight, the similarity function can more accurately represent reality.   

**When** an event occurs is a very important concept ignored in the simple model. If a person `like`d the `hobbit` today, and a `x-men` last year; they are probably more receptive to recommendations like the `hobbit`. To handle this, every event has an attached date of when it most recently occurred and:

* The most recent events (defined using a variable for a number of days) are weighted higher than past events, done by calculating multiple Jaccard similarities with a weighted mean. *Note: this may break the symmetry of our similarity function, further mathematicians are required*
 
Recommending something that a person has already actioned (e.g. bought) could be undesirable. By providing a list of the actions to filter recommendations, selected recommendations can be removed if they occurred in a persons history. For example, it makes sense to filter `hate` actions to stop recommending things they clearly don't want. However, they could potentially still receive recommendations for things they may have already `like`d, because every year they might like to re-watch movies again.

A single highly similar person can cause bad recommendations by disproportionately dominating the recommendation weights. To mitigate this risk GER encourages recommendations that are recommended by multiple people. Using the `crowd_weight` concept which makes the weight of a recommendation more than just the sum of the peoples weights by also including how many people recommended it.

## Limitations

When dealing with large sets of data practical limitations are necessary to ensure performance. Here is the list of limitations imposed on the above model and features.

### Model Limitations

The first limitation is to not generate recommendations for a person that has under a **minimum amount of history**. For example, if a person has only `like`d one movie, their generated recommendations will probably be random. In this case GER return no recommendations and lets the client handle this situation.

The most expensive aspect of GER is finding and calculating similarity between people. This is especially expensive for any person who has a large history **and every person they are similar to**. Given that a person with a large history is similar to many people, only a few such people can significantly decrease the performance of the entire engine. To ensure this is not the case, a few limitations were put in place:

1. Limit the number of similar people to find, while attempting to find the most similar people for a users recent activity
2. Limit the size of the history when calculating similarities

Finding and weighting every potential recommendation from all similar people may also be expensive and returning every recommendation is likely superfluous. For this the limitations in place are:

1. Only recommend the most recent events from the similar users
2. Only return a number of the best recommendations

Limiting the number of similar people, the length of their history, and the amount of recommendations to find, all have different performance and accuracy impacts **per data-set**. Finding the best values for these is a learning process through trial and error. 

An important aspect to note about these limits is that they may create the potential for abuse and malicious manipulation of the recommendations. A way to see this is by considering a person who `hate`s all movies, but only `like`s one. The implications of such a user are:

1. They will be similar to all people who have `hate`d anything
2. Due to limiting history size, they may be a much higher similarity than they would otherwise have been
3. Every person would include in their potential recommendations the movie the malicious person `like`s

Therefore, a person who profits from manipulating recommendations of other users, may attempt to manipulate the system this way.

###Data-set Compacting Limitations

Given the above description, it is cleat that some events will never be used. For example, if the event are old or belong to a user who has a long history they will not be used in any calculations. These events just loiter, take up space and slow calculations down. By trying to identify these events with some basic heuristics and removing them, it can dramatically speed up performance and decreases the size of the data-set. I call these compacting algorithms.

Currently there are two main compacting algorithms:

1. Limit the number of events per person, per action, e.g. ensure `bob` has a maximum of 1000 `hate`s.
1. Limit the number of events per thing, per action, e.g. ensure that a `hobbit` only has 1000 `hate`s.

These compacting algorithms delete the oldest events first as newer events carry more practical importance. They also solve the problem stated above about the malicious user who `hate`s everything, as their history will be reduced and they will be similar to less people.

Like the other limitations, the numbers associated with the compacting limitations are data-set specific, and can probably be best found through trial and error.

#The Algorithmic Description

The API for recommendations follows the core model and accepts a `person` and an `action` and returns a list of weighted things by following these steps:

1. Find similar people to `person` by looking at their history (*limiting the number of returned similar people*)
2. Calculate the similarities from `person` to the list of people (*limiting the amount of history*)
3. Find a list of the most recent `thing`s the similar people have `action`ed (*limiting the number returned*)
4. Calculating the weights of `thing`s using the similarity of the people (*additionally weighting the `crowd_weight`, filtering based on filter actions, then retuning the highest weighted*)

# Technology

GER is implemented in Coffee-Script on top of Node.js ([here](http://www.maori.geek.nz/post/why_should_you_use_coffeescript_instead_of_javascript) are my reasons for using Coffee-Script). The core logic is implemented in an abstractions called an Event Store Manager (**ESM**), this is the persistency and many calculations occur.

Currently there is an in memory ESM and a PostgreSQL ESM. There is also a RethinkDB ESM in the works being implemented by the awesome [linuxlich](https://github.com/thelinuxlich/ger).

##Event Store Manager

The API for Initialization

1. `esm = new ESM(namespace, options = {})`
2. `initialize()` will create resources necessary for ESM to function for namespace
3. `destroy()` will destroy all resources for ESM in namespace
4, `exists()` will check if the namespace exists

The API for the ESM to generate recommendations is:

1. `get_actions()` returns the actions with weights e.g. {'like': 1}
2. `find_similar_people(person, action, actions, limits...)` returns 
3. `calculate_similarities_from_person(person, people, actions, limits...)`
4. `recently_actioned_things_by_people(people)`
5. `person_history_count`
6. `filter_things_by_previous_actions`

The API for the ESM to insert data is:

1. `add_event`
2. `count_events` and `estimate_event_count`
2. `set_action_weight` (and `get_action_weight`)
3. `bootstrap`

The API for the ESM to search and manipulate the events store:

1. `find_events(person, action, thing)` at least one of the arguments must be provided
2. `delete_events(person, action, thing)` at least one of the arguments must be provided

The API for the ESM to compact the database is:

1. `pre_compact`
2. `compact_people`
3. `compact_things`
4. `expire_events`
5. `post_compact`


#Changelog

2014-12-30 - added find and delete events methods.

2014-12-22 - added exists to check if namespace is initilaized. also changed some indexes in rethinkdb, and changed some semantics around initialize 

2014-12-22 - Added Rethink DB Event Store Manager.

2014-12-9 - Added more explanation to the returned recommendations so they can be reasoned about externally

2014-12-4 - Changed ESM API to be more understandable and also updated README

2014-11-27 - Started returning the last actioned at date with recommendations

2014-11-25 - Added better way of selecting recommendations from similar people.

2014-11-12 - Added better heuristic to select related people. Meaning less related people need to be selected to find good values
