'use strict';

var Pool = require('./lib/pool'),
    Cluster = require('./lib/cluster');

Pool.Cluster = Cluster;
module.exports = Pool;
