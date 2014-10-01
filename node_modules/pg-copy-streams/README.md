## pg-copy-streams

COPY FROM / COPY TO for node-postgres.  Stream from one database to another, and stuff.

## how? what? huh?

Did you know the _all powerful_ PostgreSQL supports streaming binary data directly into and out of a table?
This means you can take your favorite CSV or TSV or whatever format file and pipe it directly into an existing PostgreSQL table.
You can also take a table and pipe it directly to a file, another database, stdout, even to `/dev/null` if you're crazy!

What this module gives you is a [Readable](http://nodejs.org/api/stream.html#stream_class_stream_readable) or [Writable](http://nodejs.org/api/stream.html#stream_class_stream_writable) stream directly into/out of a table in your database.
This mode of interfacing with your table is _very fast_ and _very brittle_.  You are responsible for properly encoding and ordering all your columns. If anything is out of place PostgreSQL will send you back an error.  The stream works within a transaction so you wont leave things in a 1/2 borked state, but it's still good to be aware of.

If you're not familiar with the feature (I wasn't either) you can read this for some good helps: http://www.postgresql.org/docs/9.3/static/sql-copy.html

## examples

### pipe from a table to stdout

```js
var pg = require('pg');
var copyTo = require('pg-copy-streams').to;

pg.connect(function(err, client, done) {
  var stream = client.query(copyTo('COPY my_table TO STDOUT'));
  stream.pipe(process.stdout);
  stream.on('end', done);
  stream.on('error', done);
});
```

### pipe from a file to table

```js
var fs = require('fs');
var pg = require('pg');
var copyFrom = require('pg-copy-streams').from;

pg.connect(function(err, client, done) {
  var stream = client.query(copyFrom('COPY my_table FROM STDIN'));
  var fileStream = fs.createReadStream('some_file.tdv')
  fileStream.on('error', done);
  fileStream.pipe(stream).on('finish', done).on('error', done);
});
```

## install

```sh
$ npm install pg-copy-streams
```

## notice

This module __only__ works with the pure JavaScript bindings.  If you're using `require('pg').native` please make sure to use normal `require('pg')` or `require('pg.js')` when you're using copy streams.

Before you set out on this magical piping journey, you _really_ should read this: http://www.postgresql.org/docs/9.3/static/sql-copy.html, and you might want to take a look at the [tests](https://github.com/brianc/node-pg-copy-streams/tree/master/test) to get an idea of how things work.

## contributing

Instead of adding a bunch more code to the already bloated [node-postgres](https://github.com/brianc/node-postgres) I am trying to make the internals extensible and work on adding edge-case features as 3rd party modules.
This is one of those.

Please, if you have any issues with this, open an issue.

Better yet, submit a pull request.  I _love_ pull requests.

Generally how I work is if you submit a few pull requests and you're interested I'll make you a contributor and give you full access to everything.

Since this isn't a module with tons of installs and dependent modules I hope we can work together on this to iterate faster here and make something really useful.

## license

The MIT License (MIT)

Copyright (c) 2013 Brian M. Carlson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
