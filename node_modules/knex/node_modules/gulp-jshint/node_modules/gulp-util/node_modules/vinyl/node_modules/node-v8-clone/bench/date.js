var assert = require('assert');
try { lodash = require('lodash'); } catch (e) {};
try { _ = require('underscore'); } catch (e) {};
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

// Date
var shared = require('./shared.js');

// node-v8-clone
var Cloner = require('..').Cloner;
cloner = new Cloner(false);

// date 'new Date(+date)' cloner
date_clone1 = function(date) { return new Date(+date); };

// date 'new Date(date)' cloner
date_clone2 = function(date) { return new Date(date); };

['date'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['new Date(+date)', 'date_clone1(' + obj + ')'],
    ['new Date(date)',  'date_clone2(' + obj + ')'],
    ['_.clone',         '_.clone(' + obj + ')'],
    ['lodash.clone',    'lodash.clone(' + obj + ', false)'],
    ['owl.copy',        'owl.copy(' + obj + ')'],
    ['node-v8-clone',   'cloner.clone(' + obj + ')']
  ]);
});
