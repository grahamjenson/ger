var assert = require('assert');
var util = require('util');

var pending = false;

module.exports.behavesAsShallow = function() {
  describe('should clone primitives', function(){
    it('should clone null', function(){
      var a = null;
      var b = this.clone(a);
      assert.equal(a, null);
      assert.equal(b, null);
      a = true;
      assert.equal(a, true);
      assert.equal(b, null);
    });
    it('should clone undefined', function(){
      var a = undefined;
      var b = this.clone(a);
      assert.equal(a, undefined);
      assert.equal(b, undefined);
    });
    it('should clone boolean', function(){
      var a = false;
      var b = this.clone(a);
      assert.equal(a, false);
      assert.equal(b, false);
      a = true;
      assert.equal(a, true);
      assert.equal(b, false);
    });
    it('should clone numbers', function(){
      var a = 1;
      var b = this.clone(a);
      assert.equal(a, 1);
      assert.equal(b, 1);
      a += 1;
      assert.equal(a, 2);
      assert.equal(b, 1);
    });
    it('should clone strings', function(){
      var a = 'aaa';
      var b = this.clone(a);
      assert.equal(a, 'aaa');
      assert.equal(b, 'aaa');
      a += 'bbb';
      assert.equal(a, 'aaabbb');
      assert.equal(b, 'aaa');
    });
  });
  describe('should clone builtin objects', function() {
    it('should clone number objects', function(){
      var a = new Number(1);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a, 1);
      assert.equal(b, 1);
    });
    it('should preserve number object custom properties', function(){
      var a = new Number(1);
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone strings objects', function(){
      var a = new String('aaa');
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a, 'aaa');
      assert.equal(b, 'aaa');
    });
    it('should preserve string object custom properties', function(){
      var a = new String('aaa');
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone {} objects', function(){
      var a = {x : 1, y: 2};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.x, 1);
      assert.equal(a.y, 2);
      assert.equal(b.x, 1);
      assert.equal(b.y, 2);
    });
    it('should clone array-like objects', function(){
      var a = { '0': 'a', '1': 'b', '2': 'c', '3': '', 'length': 5 };
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.constructor === b.constructor);
      assert.equal(a[0], 'a');
      assert.equal(a[1], 'b');
      assert.equal(a[2], 'c');
      assert.equal(a[3], '');
      assert.equal(a.length, 5);
      assert.equal(b[0], 'a');
      assert.equal(b[1], 'b');
      assert.equal(b[2], 'c');
      assert.equal(b[3], '');
      assert.equal(b.length, 5);
    });
    it('should preserve {} non-enumerable properties', function(){
      var a = {x : 1};
      Object.defineProperty(a, 'y', {value: 2});
      assert.deepEqual(Object.keys(a), ['x']);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.x, 1);
      assert.equal(a.y, 2);
      assert.equal(b.x, 1);
      assert.equal(b.y, 2);
    });
    it('should clone Object.create(null) objects', function(){
      var a = Object.create(null);
      a.x = 1;
      a.y = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.x, 1);
      assert.equal(a.y, 2);
      assert.equal(b.x, 1);
      assert.equal(b.y, 2);
    });
    it('should clone inherited objects', function(){
      var a = Object.create({ q: 1 });
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.q, 1);
      assert.equal(b.q, 1);
      assert.ok(a.__proto__ === b.__proto__);
    });
    it('should clone arrays', function(){
      var a = [1, 2];
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a[0], 1);
      assert.equal(a[1], 2);
      assert.equal(b[0], 1);
      assert.equal(b[1], 2);
    });
    it('should preserve array custom properties', function(){
      var a = [1, 2];
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone Date instances', function(){
      var a = new Date(1980,2,3,4,5,6);
      var b = this.clone(a);
      assert.equal(a.getFullYear(), 1980);
      assert.equal(b.getFullYear(), 1980);
      a.setFullYear(1981);
      assert.equal(a.getFullYear(), 1981);
      assert.equal(b.getFullYear(), 1980);
    });
    it('should preserve Date instances custom properties', function(){
      var a = new Date(1980,2,3,4,5,6);
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone RegExp instances', function(){
      var a = new RegExp('a+', 'g');
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a instanceof RegExp);
      assert.ok(b instanceof RegExp);
      assert.equal(a.lastIndex, 0);
      assert.equal(b.lastIndex, 0);
      a.exec('bba');
      assert.equal(a.lastIndex, 3);
      assert.equal(b.lastIndex, 0);
    });
    it('should preserve RegExp lastIndex property', function(){
      var a = new RegExp('a+', 'g');
      a.exec('a aa');
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.lastIndex, 1);
      assert.equal(b.lastIndex, 1);
      a.exec('a aa');
      assert.equal(a.lastIndex, 4);
      assert.equal(b.lastIndex, 1);
      b.exec('a aa');
      assert.equal(a.lastIndex, 4);
      assert.equal(b.lastIndex, 4);
    });
    it('should preserve RegExp instances custom properties', function(){
      var a = new RegExp('a+', 'g');
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone Arguments of function()', function(){
      function getargs() { return arguments; };
      var a = getargs(1, 2);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.deepEqual(a, getargs(1, 2));
      assert.deepEqual(b, getargs(1, 2));
      a[0] = 4;
      assert.deepEqual(a, getargs(4, 2));
      assert.deepEqual(b, getargs(1, 2));
    });
    it('should clone Arguments of function(x)', pending, function(){
      function getargs(x) { return arguments; };
      var a = getargs(1, 2);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.deepEqual(a, getargs(1, 2));
      assert.deepEqual(b, getargs(1, 2));
      a[0] = 4;
      assert.deepEqual(a, getargs(4, 2));
      assert.deepEqual(b, getargs(1, 2));
    });
    it('should preserve Arguments custom properties', function(){
      function getargs() { return arguments; };
      var a = getargs(1, 2, 3);
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone Functions', function(){
      var a = function(a, b, c) {};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.toString(), b.toString());
    });
    it('should preserve Functions custom properties', function(){
      var a = function(a, b, c) {};
      a.myprop = 2;
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.myprop, 2);
      assert.equal(b.myprop, 2);
    });
    it('should clone closures context', pending, function(){
      var generator = function () { var i = 0; return function() { return ++i; }; };
      var a = generator();
      assert.equal(a(), 1);
      assert.equal(a(), 2);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a(), 3);
      assert.equal(a(), 4);
      assert.equal(b(), 3);
      assert.equal(b(), 4);
    });
    it('should clone Buffer objects', pending, function(){
      var a = new Buffer('test', 'utf-8');
      console.log(Object.getOwnPropertyNames(a));
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.toString(), 'test');
      assert.equal(b.toString(), 'test');
      a.fill('a');
      assert.equal(a.toString(), 'aaaa');
      assert.equal(b.toString(), 'test');
    });
  });
  describe('should clone custom objects', function(){
    it('should clone instances', function(){
      function clazz (c) { this.c = c; this.d = 2 };
      clazz.prototype.getC = function() { return this.c; };
      var a = new clazz(1);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.equal(a.c, 1);
      assert.equal(a.getC(), 1);
      assert.equal(a.d, 2);
      assert.equal(b.c, 1);
      assert.equal(b.getC(), 1);
      assert.equal(b.d, 2);
      a.c = 3;
      assert.equal(a.c, 3);
      assert.equal(a.getC(), 3);
      assert.equal(a.d, 2);
      assert.equal(b.c, 1);
      assert.equal(b.getC(), 1);
      assert.equal(b.d, 2);
    });
    it('should clone inherited instances', function(){
      var clazz1 = function(c) { this.c = c };
      clazz1.prototype.e = 1;
      var clazz2 = function (c) { this.c = c };
      util.inherits(clazz2, clazz1);
      clazz2.prototype.d = 2;
      var a = new clazz2(3);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.hasOwnProperty('c'));
      assert.ok(b.hasOwnProperty('c'));
      assert.ok(!a.hasOwnProperty('e'));
      assert.ok(!b.hasOwnProperty('e'));
      assert.ok(!a.hasOwnProperty('d'));
      assert.ok(!b.hasOwnProperty('d'));
      assert.equal(a.c, b.c);
      assert.equal(a.e, b.e);
      assert.equal(a.d, b.d);
    });
  });
};

module.exports.behavesAsDeep = function() {
  describe('should deeply clone objects', function(){
    it('should deeply clone BooleanObject instances custom properties', function() {
      var a = new Boolean(true);
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone NumberObject instances custom properties', function() {
      var a = new Number(true);
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone StringObject instances custom properties', function() {
      var a = new String(true);
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone Function custom properties', function() {
      var a = function() {};
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone Date instances custom properties', function() {
      var a = new Date();
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone RegExp instances custom properties', function() {
      var a = /a/;
      a.myprop = {x: 1};
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.myprop !== b.myprop);
      assert.ok(a.myprop.x === b.myprop.x);
      assert.deepEqual(a.myprop, b.myprop);
    });
    it('should deeply clone nested objects', function(){
      var a = {x : {z : 1}, y: 2};
      var b = this.clone(a);
      assert.equal(a.x.z, 1);
      assert.equal(a.y, 2);
      assert.equal(b.x.z, 1);
      assert.equal(b.y, 2);
      a.x.z = 3;
      assert.equal(a.x.z, 3);
      assert.equal(a.y, 2);
      assert.equal(b.x.z, 1);
      assert.equal(b.y, 2);
    });
    it('should deeply clone {} non-enumerable properties', pending, function(){
      var a = {x : 1};
      Object.defineProperty(a, 'y', {enumerable: false, configurable: true, writable: true, value: {z: 3}});
      assert.deepEqual(Object.keys(a), ['x']);
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a.y !== b.y);
      assert.equal(a.x, 1);
      assert.equal(a.y.z, 3);
      assert.equal(b.x, 1);
      assert.equal(b.y.z, 3);
    });
    it('should deeply clone nested arrays', function(){
      var a = [[1], 2];
      var b = this.clone(a);
      assert.deepEqual(a, [[1], 2]);
      assert.deepEqual(b, [[1], 2]);
      a[0][0] = 3;
      assert.deepEqual(a, [[3], 2]);
      assert.deepEqual(b, [[1], 2]);
    });
    it('should deeply clone arrays with custom properties', function(){
      var a = [{ n: 1 }, { n: 2 }];
      a.x = { n: 3 };
      var b = this.clone(a);
      assert.equal(a[0].n, 1);
      assert.equal(a[1].n, 2);
      assert.equal(a.x.n, 3);
      assert.equal(b[0].n, 1);
      assert.equal(b[1].n, 2);
      assert.equal(b.x.n, 3);
      assert.ok(a !== b);
      assert.ok(a[0] !== b[0]);
      assert.ok(a[1] !== b[1]);
      assert.ok(a.x !== b.x);
    });
  });
};

module.exports.behavesAsDeepWCircular = function() {
  describe('should deeply clone circular objects', function(){
    it('should clone nested objects with internal refs', function() {
      var r = [1];
      var a = [r, r];
      var b = this.clone(a);
      assert.ok(a !== b);
      assert.ok(a[0] === a[1]);
      assert.ok(a[0] !== b[0]);
      assert.ok(b[0] === b[1]);
    });
    it('should deeply clone circular arrays', function(){
      var a = [[1], 2];
      a.push(a);
      var b = this.clone(a);
      assert.equal(a[0][0], 1);
      assert.equal(a[1], 2);
      assert.equal(a[2][0][0], 1);
      assert.equal(b[0][0], 1);
      assert.equal(b[1], 2);
      assert.equal(b[2][0][0], 1);
      a[0][0] = 3;
      assert.equal(a[0][0], 3);
      assert.equal(a[1], 2);
      assert.equal(a[2][0][0], 3);
      assert.equal(b[0][0], 1);
      assert.equal(b[1], 2);
      assert.equal(b[2][0][0], 1);
    });
    it('should deeply clone circular objects', function(){
      var a = {x: {y: 1}, z: null};
      a.z = a;
      var b = this.clone(a);
      assert.equal(a.x.y, 1);
      assert.equal(a.z.x.y, 1);
      assert.equal(b.x.y, 1);
      assert.equal(b.z.x.y, 1);
      a.z.z.z.x.y = 2;
      assert.equal(a.x.y, 2);
      assert.equal(a.z.x.y, 2);
      assert.equal(b.x.y, 1);
      assert.equal(b.z.x.y, 1);
    });
    it('should deeply clone circular objects (lodash version)', function(){
      var object = {
        'foo': { 'b': { 'foo': { 'c': { } } } },
        'bar': { }
      };

      object.foo.b.foo.c = object;
      object.bar.b = object.foo.b;
      var cloned = this.clone(object);
      assert.ok(cloned.bar.b === cloned.foo.b && cloned === cloned.foo.b.foo.c && cloned !== object);
    });
  });
};
