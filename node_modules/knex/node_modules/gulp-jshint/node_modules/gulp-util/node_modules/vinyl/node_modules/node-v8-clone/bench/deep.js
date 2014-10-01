var assert = require('assert');
try { lodash = require('lodash'); } catch (e) { console.warn('lodash module is not installed'); };
try { clone = require('clone'); } catch(e) { console.warn('clone module is not installed'); };
try { cloneextend = require('cloneextend'); } catch(e) { console.warn('cloneextend module is not installed'); };
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

var shared = require('./shared.js');

// cloner
var Cloner = require('..').Cloner;
cloner = new Cloner(true);

['deepobj1', 'deepobj2', 'deepobj3', 'deepobj4', 'mixed1', 'mixed2', 'mixed3', 'mixed4'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['lodash.clone',  'lodash.clone(' + obj + ', true)'],
    ['clone',         'clone(' + obj + ')'],
    ['cloneextend',   'cloneextend.clone(' + obj + ')'],
    ['owl.deepCopy',  'owl.deepCopy(' + obj + ')'],
    ['node-v8-clone', 'cloner.clone(' + obj + ')']
  ]);
});
