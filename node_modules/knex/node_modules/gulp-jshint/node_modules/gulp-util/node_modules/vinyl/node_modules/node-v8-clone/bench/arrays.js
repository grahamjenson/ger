var assert = require('assert');
try { lodash = require('lodash'); } catch (e) {};
try { _ = require('underscore'); } catch (e) {};
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

shared = require('./shared.js');

// node-v8-clone js
var Cloner = require('..').Cloner;
cloner = new Cloner(false);

// slice
slice = function(a) { return a.slice(); };

// array 'for (var i = 0; i < l; i++)' cloner
arr_for1 = function(a) { var b = []; for (var i = 0, l = a.length; i < l; i++) b.push(a[i]); return b; }

// array 'for (var i = 0; i < l; i++)' cloner
arr_for2 = function(a) { var b = []; for (var i = 0, l = a.length; i < l; i++) b[i] = a[i]; return b; }

// array 'for (var i = 0; i < l; i++)' cloner 2
arr_for3 = function(a) { var l = a.length, b = new Array(l); for (var i = 0; i < l; i++) b[i] = a[i]; return b; }

// array 'for (var i = 0; i < l; i++)' cloner 3
arr_for4 = function(a) { var l = a.length, b = new Array(); for (var i = 0; i < l; i++) b[i] = a[i]; return b; }

// array 'for (i in arr)' cloner
arr_for_in = function(a) { var b = []; for(var i in a) b.push(a[i]); return b; }

// array 'for (i in arr) if (hasOwnProperty)' cloner
arr_for_in_has = function(a) { var b = []; for(var i in a) if (a.hasOwnProperty(i)) b.push(a[i]); return b; }

// hybrid
hybrid = function(a) { return (a.length > 100) ? a.slice() : arr_for3(a); };

['arr1', 'arr2', 'arr3', 'arr4', 'arr5', 'arr6'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['slice',                        'slice(' + obj + ')'],
    ['[] for i++ push',              'arr_for1(' + obj + ')'],
    ['[] for i++ b[i] = a[i]',       'arr_for2(' + obj + ')'],
    ['Array(l) for i++ b[i] = a[i]', 'arr_for3(' + obj + ')'],
    //['Array() ++',                   'arr_for4(' + obj + ')'], // same as "[] for i++ b[i] = a[i]"
    //['hybrid',                       'hybrid(' + obj + ')'],
    ['for in',                       'arr_for_in(' + obj + ')'],
    ['for in hasOwnProperty',        'arr_for_in_has(' + obj + ')'],
    ['lodash.clone',                 'lodash.clone(' + obj + ', false)'],
    ['_.clone',                      '_.clone(' + obj + ')'],
    ['owl.copy',                     'owl.copy(' + obj + ')'],
    ['node-v8-clone',                'cloner.clone(' + obj + ')']
  ]);
});
