var assert = require('assert');
try { lodash = require('lodash'); } catch (e) {};
try { _ = require('underscore'); } catch (e) {};
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

shared = require('./shared.js');

// node-v8-clone js
var Cloner = require('..').Cloner;
cloner = new Cloner(false);

['instance'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['Clazz.clone()', obj + '.clone()'],
    ['lodash.clone',  'lodash.clone(' + obj + ')'],
    ['_.clone',       '_.clone(' + obj + ')'],
    ['owl.copy',      'owl.copy(' + obj + ')'],
    ['node-v8-clone', 'cloner.clone(' + obj + ')']
  ]);
});
