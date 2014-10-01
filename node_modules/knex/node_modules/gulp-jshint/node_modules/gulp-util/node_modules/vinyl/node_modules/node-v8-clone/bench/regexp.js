var assert = require('assert');
try { lodash = require('lodash'); } catch (e) {};
try { _ = require('underscore'); } catch (e) {};
try { owl = require('owl-deepcopy'); } catch(e) { console.warn('owl-deepcopy module is not installed'); };

var shared = require('./shared.js');

// node-v8-clone
var Cloner = require('..').Cloner;
cloner = new Cloner(false);

// RegExp 'new RegExp(re)' cloner
re_clone1 = function(re) { return new RegExp(re); };

// RegExp 'new RegExp(re.source, /\w*$/.exec(re))' cloner
reFlags = /\w*$/;
re_clone2 = function(re) { return new RegExp(re.source, reFlags.exec(re)); };

// RegExp 'new RegExp(source, flags)' cloner
re_clone3 = function(re) {
  var flags = (re.global ? 'g' : '') + (re.ignoreCase ? 'i' : '') + (re.multiline ? 'm' : '');
  return new RegExp(re.source, flags);
};

['re'].forEach(function(obj) {
  global[obj] = shared[obj];
  shared.benchmark(obj, [
    ['new RegExp(re)',                            're_clone1(re)'],
    //['new RegExp(re.source, /\\w*$/.exec(re))',   're_clone2(re)'],
    ['new RegExp(re.source, g?+i?+m?)',           're_clone3(re)'],
    ['_.clone',                                   '_.clone(re)'],
    ['lodash.clone',                              'lodash.clone(re, false)'],
    ['node-v8-clone',                             'cloner.clone(re, false)']
  ]);
});
