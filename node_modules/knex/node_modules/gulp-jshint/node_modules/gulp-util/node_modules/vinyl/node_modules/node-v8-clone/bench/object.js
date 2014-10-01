var assert = require('assert');
try { lodash = require('lodash'); } catch (e) {};
try { _ = require('underscore'); } catch (e) {};
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

var shared = require('./shared.js');

// regular for(var i in obj) cloner
regular = function(obj) { var result = {}; for(var i in obj) result[i] = obj[i]; return result; };

// regular cloner with own checks
regular_own = function(obj) { var result = {}; for(var i in obj) if (obj.hasOwnProperty(i)) result[i] = obj[i]; return result; };

// regular cloner with own checks
regular_keys = function(obj) { var result = {}; var props = Object.keys(obj); for(var i = 0, l = props.length; i < l; i++) result[i] = obj[i]; return result; };

var Cloner = require('..').Cloner;
cloner = new Cloner(false);

['objs1', 'objs2', 'objs3', 'objs4', 'objs5', 'objn1', 'objn2', 'objn3', 'objn4', 'objn5'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['for in',        'regular(' + obj + ')'],
    ['for own',       'regular_own(' + obj + ')'],
    ['for Obj.keys',  'regular_keys(' + obj + ')'],
    ['lodash.clone',  'lodash.clone(' + obj + ', false)'],
    ['_.clone',       '_.clone(' + obj + ')'],
    ['owl.copy',      'owl.copy(' + obj + ')'],
    ['node-v8-clone', 'cloner.clone(' + obj + ')']
  ]);
});