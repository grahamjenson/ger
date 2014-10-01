var assert = require('assert');
try { lodash = require('lodash'); } catch (e) { console.warn('lodash module is not installed'); };
try { clone = require('clone'); } catch(e) { console.warn('clone module is not installed'); };
try { cloneextend = require('cloneextend'); } catch(e) { console.warn('cloneextend module is not installed'); };
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

var shared = require('./shared.js');

// node-v8-clone
var Cloner = require('..').Cloner;
cloner1 = new Cloner(true);
cloner2 = new Cloner(true, { 'Array': Cloner.deep_array });

['deeparr1', 'deeparr2', 'deepplainarr1', 'deepplainarr2', 'deepplainarr3', 'deepplainarr4', 'deepplainarr5', 'deepplainarr6'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['lodash.clone',      'lodash.clone(' + obj + ', true)'],
    ['clone',             'clone(' + obj + ')'],
    ['cloneextend',       'cloneextend.clone(' + obj + ')'],
    ['owl.deepCopy',      'owl.deepCopy(' + obj + ')'],
    ['node-v8-clone',     'cloner1.clone(' + obj + ')'],
    ['node-v8-clone opt', 'cloner2.clone(' + obj + ')']
  ]);
});
