'use strict';

var HashMap = require('hashmap'),
    Pool = require('./pool');
    
var inherits = require('util').inherits,
    EventEmitter = require('events').EventEmitter;

function Cluster(pools) {
    EventEmitter.call(this);
    
    if (!pools) { pools = [ ]; }
    else if (!Array.isArray(pools)) { pools = [ pools ]; }
    
    this.pools = [ ];
    this.caps = { };
    this.removeListeners = new HashMap();
    this.sources = new HashMap();

    this.ended = false;
    
    pools.forEach(this.addPool, this);
}
inherits(Cluster, EventEmitter);

Cluster.prototype.addPool = function (pool) {
    if (this.ended) {
        throw new Error('Cluster.addPool(): Cluster is ended');
    }
    if (!(pool instanceof Pool)) {
        throw new Error('Cluster.addPool(): Not a valid pool');
    }
    if (this.pools.indexOf(pool) > -1) {
        throw new Error('Cluster.addPool(): Pool already in cluster');
    }
    
    this.pools.push(pool);
    this._bindListeners(pool);
    this._addCapabilities(pool);
};
Cluster.prototype.removePool = function (pool) {
    if (!(pool instanceof Pool)) {
        throw new Error('Cluster.removePool(): Not a valid pool');
    }
    var idx = this.pools.indexOf(pool);
    if (idx === -1) {
        throw new Error('Cluster.removePool(): Pool not in cluster');
    }
    
    this.pools.splice(idx, 1);
    this._unbindListeners(pool);
    this._removeCapabilities(pool);
};
Cluster.prototype.acquire = function (cap, cb) { // jshint maxstatements: 20, maxcomplexity: 8
    if (typeof cap === 'function') {
        cb = cap;
        cap = void 0;
    }
    if (typeof cb !== 'function') {
        this.emit('error', new Error('Cluster.acquire(): Callback is required'));
        return;
    }
    if (this.ended) {
        cb(new Error('Cluster.acquire(): Cluster is ended'));
        return;
    }
    
    var sources = this.pools;
    if (cap) {
        if (!this.caps[cap] || !this.caps[cap].length) {
            cb(new Error('Cluster.acquire(): No pools can fulfil capability: ' + cap));
            return;
        }
        sources = this.caps[cap];
    }
    
    var pool = sources.filter(function (pool) {
        var stats = pool.stats();
        return stats.queued < stats.maxRequests;
    }).sort(function (a, b) {
        var statsA = a.stats(),
            statsB = b.stats();

        return (statsB.available - statsB.queued) - (statsA.available - statsA.queued);
    })[0];
    
    if (!pool) {
        cb(new Error('Cluster.acquire(): No pools available'));
        return;
    }
    
    pool.acquire(function (err, res) {
        if (err) { cb(err); return; }
        this.sources.set(res, pool);
        process.nextTick(cb.bind(null, null, res));
    }.bind(this));
};
Cluster.prototype.release = function (res) {
    if (!this.sources.has(res)) {
        var err = new Error('Cluster.release(): Unknown resource');
        err.res = res;
        this.emit('error', err);
        return;
    }
    var pool = this.sources.get(res);
    this.sources.remove(res);
    pool.release(res);
};
Cluster.prototype.end = function (cb) {
    if (this.ended) {
        if (typeof cb === 'function') {
            cb(new Error('Cluster.end(): Cluster is already ended'));
        }
        return;
    }

    this.ended = true;
    
    var count = this.pools.length,
        errs = [ ];
    
    this.pools.forEach(function (pool) {
        pool.end(function (err, res) {
            this.removePool(pool);
            if (err) { errs.concat(err); }
            count--;
            if (count === 0 && typeof cb === 'function') {
                cb(errs.length ? errs : null);
            }
        }.bind(this));
    }, this);
};

Cluster.prototype._addCapabilities = function (pool) {
    if (!pool.capabilities || !Array.isArray(pool.capabilities)) { return; }
    pool.capabilities.forEach(function (cap) {
        if (typeof cap !== 'string') { return; }
        this.caps[cap] = this.caps[cap] || [ ];
        this.caps[cap].push(pool);
    }, this);
};
Cluster.prototype._removeCapabilities = function (pool) {
    if (!pool.capabilities || !Array.isArray(pool.capabilities)) { return; }
    pool.capabilities.forEach(function (cap) {
        if (typeof cap !== 'string' || !Array.isArray(this.caps[cap])) { return; }
        var idx = this.caps[cap].indexOf(pool);
        if (idx > -1) { this.caps[cap].splice(idx, 1); }
    }, this);
};
Cluster.prototype._bindListeners = function (pool) {
    var onError, onWarn;

    onError = function (err) {
        err.source = pool;
        this.emit('error', err);
    }.bind(this);
    
    onWarn = function (err) {
        err.source = pool;
        this.emit('warn', err);
    }.bind(this);
    
    pool.on('error', onError);
    pool.on('warn', onWarn);
    
    this.removeListeners.set(pool, function () {
        pool.removeListener('error', onError);
        pool.removeListener('warn', onWarn);
    });
};
Cluster.prototype._unbindListeners = function (pool) {
    this.removeListeners.get(pool)();
    this.removeListeners.remove(pool);
};


module.exports = Cluster;
