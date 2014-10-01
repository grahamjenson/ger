var assert = require('assert');
var lodash = require('lodash');
var _ = require('underscore');
var shared = require('./shared.js');
var cloneextend = require('cloneextend');
var clone = require('clone');
var owl = require('owl-deepcopy');

describe('lodash.clone(value)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return lodash.clone(value);
    };
  });
  shared.behavesAsShallow();
});

describe('lodash.clone(value, true)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return lodash.clone(value, true);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});

describe('cloneextend.clone()', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return cloneextend.clone(value);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});

describe('clone()', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return clone(value);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});
describe('underscore.clone(value)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return _.clone(value, true);
    };
  });
  shared.behavesAsShallow();
});

describe('owl.copy(value)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return owl.copy(value);
    };
  });
  shared.behavesAsShallow();
});

describe('owl.deepcopy(value)', function(){
  beforeEach(function(){
    this.clone = function(value) {
      return owl.deepCopy(value);
    };
  });
  shared.behavesAsShallow();
  shared.behavesAsDeep();
  shared.behavesAsDeepWCircular();
});
