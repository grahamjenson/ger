// require the ger objects
var g = require('../ger')

// Create an Event Store Manager (ESM) that stores events and provides functions to query them
var esm = new g.MemESM()

// Initialize GER with the esm
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
