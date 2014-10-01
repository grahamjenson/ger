var clone = require('..').clone;
var a = {a: 1, b: 2, c: 3};
var b = clone(a);
a.a = 10;
console.log(a);
console.log(b);