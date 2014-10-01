var assert = require('assert');
var Cloner = require('..').Cloner;
var clone = require('..').clone;
var shared = require('./shared.js');

describe('node-v8-clone.clone(obj, false)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return clone(value);
    };
  });
  shared.behavesAsShallow();
});

describe('node-v8-clone.clone(obj, true)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return clone(value, true);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});


describe('new Cloner(false)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      var cloner = new Cloner(false);
      return cloner.clone(value);
    };
  });
  shared.behavesAsShallow();
});

describe('new Cloner(true)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      var cloner = new Cloner(true);
      return cloner.clone(value);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});

describe('new Cloner(true) without circular checks', function(){
  beforeEach(function(){
    this.clone = function(value) {
      var cloner = new Cloner(true);
      cloner.setCircularChecks(false);
      return cloner.clone(value);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
});
