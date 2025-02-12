// require the ger objects
const g = require('../ger')

// Create an Event Store Manager (ESM) that stores events and provides functions to query them
const esm = new g.MemESM()

// Initialize GER with the esm
const ger = new g.GER(esm);

 // recommender.addProductLikeEvent("18293706430499707810", "16881384362748939725")
  // recommender.addProductLikeEvent("16902649705179035005", "16916506858972910735")
  // recommender.addProductLikeEvent("18293706430499707811", "16881384362748939725")
  // recommender.addProductLikeEvent("16902649705179035005", "16881384362748939725")
  
ger.initialize_namespace('fruites')
.then( function() {
  return ger.events([
    { 
      namespace: 'fruites', 
      person: 'alice', 
      action: 'eats', 
      thing: 'mango',
      expires_at: '2024-10-06' 
    },
    { 
      namespace: 'fruites', 
      person: 'bob', 
      action: 'eats', 
      thing: 'mango',
      expires_at: '2024-10-06' 
    },
    { 
      namespace: 'fruites', 
      person: 'bob', 
      action: 'eats', 
      thing: 'guave',
      expires_at: '2024-10-06' 
    }
  ])
})
.then( function() {
  // What things might alice like?
  return ger.recommendations_for_person('fruites', 'alice', {actions: {eats: 1}})
})
.then( function(recommendations) {
  console.log("\nRecommendations For 'alice'")
  console.log(JSON.stringify(recommendations,null,2))
})
.then( function() {
  // What things are similar to xmen?
  return ger.recommendations_for_thing('fruites', 'guave', {actions: {eats: 1}})
})
.then( function(recommendations) {
  console.log("\nRecommendations Like 'guave'")
  console.log(JSON.stringify(recommendations,null,2))
})
