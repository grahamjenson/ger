/**
 * Use an optimized version for deep array cloning.
 * This version will use
 * for (var i = 0; i < arr.length; i++)
 * algorithm instead of iterating over all Object.keys(arr) properties.
 */
var Cloner = require('..').Cloner;
var c = new Cloner(true, { 'Array': Cloner.deep_array });
var a = [[1], [2], [3]];
var b = c.clone(a);
console.log(a);
console.log(b);