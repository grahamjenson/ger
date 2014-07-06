var parse = require('../').getTypeParser(1114, 'text');
var assert = require('./assert')

//some of these tests might be redundant
//they were ported over from node-postgres
//regardles: more tests is a good thing, right? :+1:
describe('date parser', function() {
  it('parses date', function() {
    assert.equal(parse("2010-12-11 09:09:04").toString(),new Date("2010-12-11 09:09:04").toString());
  });

  var testForMs = function(part, expected) {
    var dateString = "2010-01-01 01:01:01" + part;
    it('testing for correcting parsing of ' + dateString, function() {
      var ms = parse(dateString).getMilliseconds();
      assert.equal(ms, expected)
    })
  }

  testForMs('.1', 100);
  testForMs('.01', 10);
  testForMs('.74', 740);

  it("dates without timezones", function() {
    var actual = "2010-12-11 09:09:04.1";
    var expected = JSON.stringify(new Date(2010,11,11,9,9,4,100))
    assert.equal(JSON.stringify(parse(actual)),expected);
  });

  it("with timezones", function() {
    var actual = "2011-01-23 22:15:51.28-06";
    var expected = "\"2011-01-24T04:15:51.280Z\"";
    assert.equal(JSON.stringify(parse(actual)),expected);
  });

  it("with huge millisecond value", function() {
    var actual = "2011-01-23 22:15:51.280843-06";
    var expected = "\"2011-01-24T04:15:51.280Z\"";
    assert.equal(JSON.stringify(parse(actual)),expected);
  });
});
