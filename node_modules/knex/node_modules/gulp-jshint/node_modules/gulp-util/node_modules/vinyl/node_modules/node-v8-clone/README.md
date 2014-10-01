# node-v8-clone

[![Build Status](https://secure.travis-ci.org/AlexeyKupershtokh/node-v8-clone.png?branch=master)](https://travis-ci.org/AlexeyKupershtokh/node-v8-clone)

It's a c++ addon for node.js that does the most accurate cloning for node.js.
It's also very fast in some cases (benchmarks inside).

### Installation:

Tested on node.js versions 0.8, 0.9, 0.10 and 0.11.13 (prior 0.11.x versions are not compatible).

You may be asked to install `make` and `g++` as well.
```
npm install node-v8-clone
```

### Usage:

```javascript
var clone = require('node-v8-clone').clone;
var a = { x: { y: {} } };

// deep clone
var b = clone(a, true);
a === b // false
a.x === b.x // false
a.x.y === b.x.y // false

// shallow clone
var c = clone(a, false);
a === c // false
a.x === c.x // true
a.x.y === c.x.y // true
```
Extended syntax:
```javascript
var Cloner = require('node-v8-clone').Cloner;
var a = [1, [2, 3, 4], 5];

// create a cloner instance for deep cloning optimized for arrays.
var c = new Cloner(true, { 'Array': Cloner.deep_array });
var b = c.clone(a);
a === b // false
a[1] === b[1] // false
```


### Benchmark results

 * [Benchmark graphs](https://github.com/AlexeyKupershtokh/node-v8-clone/wiki/Benchmark-graphs).
 * [Raw benchmark results](https://github.com/AlexeyKupershtokh/node-v8-clone/wiki/Raw-benchmark-results).

### Running tests

For running tests you'll need to install dev dependencies at first (run in node-v8-clone dir):
```
$ npm install
```

To run tests for node-v8-clone run:
```
$ npm test
```

To run tests for 3rdparty modules run:
```
$ npm run-script benchmark-prepare
$ npm run-script test-3rdparty
```

Test results are available [here](https://github.com/AlexeyKupershtokh/node-v8-clone/wiki/Test-results).

Also you may want to check the [module's page at Travis CI](https://travis-ci.org/AlexeyKupershtokh/node-v8-clone).
