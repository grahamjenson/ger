# Pool2

A generic resource pool

## Usage

    var Pool = require('pool2');
    var pool = new Pool({
        acquire: function (cb) { cb(null, resource); },
        acquireTimeout: 30*1000,

        dispose: function (res, cb) { cb(); },
        disposeTimeout: 30*1000,

        destroy: function () { },

        ping: function (res, cb) { cb(); },
        pingTimeout: 10*1000,

        capabilities: ['tags'],

        min: 0,
        max: 10,

        idleTimeout: 60*1000,
        syncInterval: 10*1000
    });

    pool.acquire(function (err, rsrc) {
        // do stuff
        pool.release(rsrc);
    });

    pool.stats();
    /* {
        min: 0,
        max: 10,
        allocated: 0,
        available: 0,
        queued: 0,
        maxRequests: Infinity
    } */

    pool.remove(rsrc);
    pool.destroy(rsrc);

    pool.end(function (errs) {
        // errs is null or an array of errors from resources that were released
    });

    pool._destroyPool();


## Clustering

    var pool1 = new Pool(opts1),
        pool2 = new Pool(opts2);
        
    var cluster = new Pool.Cluster([pool1, pool2]);
    
    cluster.acquire(function (err, rsrc) {
        // do stuff
        cluster.release(rsrc);
    });
    
    cluster.acquire('read', function (err, rsrc) {
        // if you specify a capability, only pools tagged with that capability
        // will be used to serve the request
    });
    
    cluster.addPool(new Pool(...));
    var pool = cluster.pools[0];
    cluster.removePool(pool);
    
    cluster.end(function (errs) {
        // errs is an array of errors returned from ending the pools
    });
