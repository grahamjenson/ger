"use strict";

var v8_clone_mod = require('bindings')('clone');
var v8_clone = v8_clone_mod.clone;

var Cloner = module.exports.Cloner = function (deep, map) {
  this._deep = !!deep;
  this.setCircularChecks(true);
  this._map = {};
  if (typeof map === 'object') {
    for (var clazz in map) if (map.hasOwnProperty(clazz)) {
      this._map[clazz] = this.getStrategy(map[clazz]);
    }
  }
};

/**
 * @see Cloner._noop
 */
Cloner.shallow = Cloner.prototype.shallow = 0;

/**
 * @see Cloner._deepCloneObjectProperties
 */
Cloner.deep = Cloner.prototype.deep = 1;

/**
 * @see Cloner._deepCloneArrayValues
 */
Cloner.deep_array = Cloner.prototype.deep_array = 2;

Cloner.prototype.getStrategy = function(flag) {
  if (flag === this.shallow)    return this._noop;
  if (flag === this.deep)       return this._deepCloneObjectProperties;
  if (flag === this.deep_array) return this._deepCloneArrayValues;
  throw new Error('Unknown strategy');
};

Cloner.prototype.setCircularChecks = function(circular) {
  this._circular = (typeof circular === 'undefined') ? true : !!circular;
  if (!this._circular) {
    this.checkCircular = function() {};
    this.addCircular = function() {};
  }
};

Cloner.prototype.clone = function(value) {
  if (this._circular) {
    this.stackA = [];
    this.stackB = [];
  }
  return this._clone(value);
};
Cloner.prototype.checkCircular = function(value) {

  var pos = this.stackA.indexOf(value);
  if (pos !== -1) {
    return this.stackB[pos];
  }
  return null;
};
Cloner.prototype.addCircular = function(value, result) {
  this.stackA.push(value);
  this.stackB.push(result);
};
Cloner.prototype._clone = function(value) {
  // based on type
  if ((value === null) || (typeof value !== 'object' && typeof value !== 'function')) {
    return value;
  }

  // shallow clone
  if (!this._deep) {
    return v8_clone(value);
  }

  // check for circular references and return corresponding clone
  var result = this.checkCircular(value);
  if (result) return result;

  // init cloned object
  result = v8_clone(value);

  // add the source value to the stack of traversed objects
  // and associate it with its clone
  this.addCircular(value, result);

  //var f = this._deepCloneObjectAllProperties;
  var f = this._deepCloneObjectProperties;
  if (value.constructor && this._map[value.constructor.name]) {
    f = this._map[value.constructor.name];
  }
  f(this, result);
  return result;
};
Cloner.prototype._deepCloneObjectProperties = function(cloner, value) {
  var props = Object.keys(value);
  for (var i = 0, l = props.length; i < l; i++)
    if (typeof value[props[i]] === 'object' || typeof value[props[i]] === 'function')
      value[props[i]] = cloner._clone(value[props[i]]);
};
Cloner.prototype._deepCloneObjectAllProperties = function(cloner, value) {
  var props = Object.getOwnPropertyNames(value);
  for (var i = 0, l = props.length; i < l; i++)
    if (typeof value[props[i]] === 'object' || typeof value[props[i]] === 'function')
      value[props[i]] = cloner._clone(value[props[i]]);
};
Cloner.prototype._deepCloneArrayValues = function(cloner, value) {
  for (var i = 0, l = value.length; i < l; i++)
    if (typeof value[i] === 'object' || typeof value[i] === 'function')
      value[i] = cloner._clone(value[i]);
};
Cloner.prototype._noop = function(cloner, value) {};

var cloner_shallow = new Cloner();
var cloner_deep = new Cloner(true);

module.exports.clone = function clone(value, deep) {
  if (deep) {
    return cloner_deep.clone(value);
  }
  return cloner_shallow.clone(value);
};