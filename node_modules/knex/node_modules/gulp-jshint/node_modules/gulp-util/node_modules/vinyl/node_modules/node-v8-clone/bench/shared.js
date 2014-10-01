var plot = require('benchmark.js-plot').plot;
var Benchmark = require('benchmark');

var range = function(n) {
  var result = [];
  for (var i = 0; i < n; i++) {
   result.push(i);
  }
  return result;
};

var random_stuff = function(i) {
  switch(i % 10) {
    case 0:
      return i;
      break;
    case 1:
      return i + 0.5;
      break;
    case 2:
      return Math.random() > 0.5;
      break;
    case 3:
      return new Date();
      break;
    case 4:
      //return /i/;
      break;
    case 5:
      //return new Function(' return ' + i);
      break;
    case 6:
      return null;
      break;
    case 7:
      return "aaaaaaa" + i;
      break;
    case 8:
      return [1, 2, 3, 's', i];
      break;
    case 9:
      return {1: 1, _2: '_2', 3: new Date(), _4: i};
      break;
  }
};

var random_arr = function(n) {
  var result = [];
  for (var i = 0; i < n; i++) {
    result.push(random_stuff(i));
  }
  return result;
};

var date = module.exports.date = new Date();

var re = module.exports.re = new RegExp('a', 'gi');

// objs1: 1 sting keys and values
var objs1 = module.exports.objs1 = {'_1': '_1'};

// objs2: 10 string keys and values
var objs2 = module.exports.objs2 = {};
for (var i = 0; i < 10; i++) {
  objs2['_' + i] = '_' + i;
}

// objs3: 100 string keys and values
var objs3 = module.exports.objs3 = {};
for (var i = 0; i < 100; i++) {
  objs3['_' + i] = '_' + i;
}

// objs4: 1000 string keys and values
var objs4 = module.exports.objs4 = {};
for (var i = 0; i < 1000; i++) {
  objs4['_' + i] = '_' + i;
}

// objs5: 10000 string keys and values
var objs5 = module.exports.objs5 = {};
for (var i = 0; i < 10000; i++) {
  objs5['_' + i] = '_' + i;
}

// objn1: 1 integer keys and values
var objn1 = module.exports.objn1 = {1: 1};

// objn2: 10 integer keys and values
var objn2 = module.exports.objn2 = {};
for (var i = 0; i < 10; i++) {
  objn2[i] = i;
}

// objn3: 100 integer keys and values
var objn3 = module.exports.objn3 = {};
for (var i = 0; i < 100; i++) {
  objn3[i] = i;
}

// objn4: 1000 integer keys and values
var objn4 = module.exports.objn4 = {};
for (var i = 0; i < 1000; i++) {
  objn4[i] = i;
}

// objn5: 10000 integer keys and values
var objn5 = module.exports.objn5 = {};
for (var i = 0; i < 10000; i++) {
  objn5[i] = i;
}

// deepobj1: 5 sting keys and values
var deepobj1 = module.exports.deepobj1 = {a: 'a', b: {c: 'c', d: 'd', e: 'e'}, f: 'f'};

// deepobj2: 5 integer keys and values
var deepobj2 = module.exports.deepobj2 = {1: 1, 2: {3: 3, 4: 4, 5: 5}, 6: 6};

// deepobj3: 100 x 1 x 3 x 3 objects with string keys and values
var deepobj3 = module.exports.deepobj3 = {};
for (var i = 0; i < 100; i++) {
  deepobj3['_' + i] = {
    a: {
      b: {c: 'c', d: 'd', e: 'e'},
      f: {g: 'g', h: 'h', i: 'i'},
      j: {k: 'k', l: 'l', m: 'm'}
    }
  };
}

// deepobj4: 100 x 1 x 3 x 3 objects with int keys and values
var deepobj4 = module.exports.deepobj4 = {};
for (var i = 0; i < 100; i++) {
  deepobj4[i] = {
    1: {
      2: {3: 3, 4: 4, 5: 5},
      6: {7: 7, 8: 8, 9: 9},
      10: {11: 11, 12: 12, 13: 13}
    }
  };
}

// array of 1 numeric elements
var arr1 = module.exports.arr1 = range(1);

// array of 10 numeric elements
var arr2 = module.exports.arr2 = range(10);

// array of 100 numeric elements
var arr3 = module.exports.arr3 = range(100);

// array of 1000 numeric elements
var arr4 = module.exports.arr4 = range(1000);

// array of 10000 numeric elements
var arr5 = module.exports.arr5 = range(10000);

// array of 100000 numeric elements
var arr6 = module.exports.arr6 = range(100000);

module.exports.deepplainarr1 = arr1;
module.exports.deepplainarr2 = arr2;
module.exports.deepplainarr3 = arr3;
module.exports.deepplainarr4 = arr4;
module.exports.deepplainarr5 = arr5;
module.exports.deepplainarr6 = arr6;

module.exports.mixed1 = random_arr(10);
module.exports.mixed2 = random_arr(100);
module.exports.mixed3 = random_arr(1000);
module.exports.mixed4 = random_arr(10000);

// deeparr1: 5 string keys and values
var deeparr1 = module.exports.deeparr1 = ['a', ['b', 'c', 'd'], 'e'];

// deeparr2: 100 x 1 x 3 x 3 nested elements with string values
var deeparr2 = module.exports.deeparr2 = [];
for (var i = 0; i < 100; i++) {
  deeparr2[i] = [
    [
      ['c', 'd', 'e'],
      ['g', 'h', 'i'],
      ['k', 'l', 'm']
    ]
  ];
}

var Clazz = module.exports.Clazz = function(a, b, c, d) {
  this.a = a;
  this.b = b;
  this.c = c;
  this.d = d;
};
Clazz.prototype.clone = function() {
  return new Clazz(this.a, this.b, this.c, this.d);
};
var instance = module.exports.instance = new Clazz(1, 2, 3, 4);

var benchmark = module.exports.benchmark = function(suite_name, benchmarks) {
  var suite = new Benchmark.Suite;
  suite.on('start', function() {
    console.log('===', suite_name, '===');
  });
  suite.on('cycle', function(event) {
    if (typeof gc == 'function') gc();
    console.log(String(event.target));
  });
  suite.on('complete', function() {
    var path = 'results/' + suite_name + '.png';
    plot(this, { path: path });
    console.log('Fastest is ' + this.filter('fastest').pluck('name'));
    console.log('written plot:', path);
    console.log();
  });

  var options = { maxTime: 1 };

  benchmarks.forEach(function(tuple) {
    var benchmark_name = tuple[0];
    var code = tuple[1];
    suite.add(benchmark_name, code, options);
  });

  suite.run();
};