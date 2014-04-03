chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

BOP = require('../back-on-promise')
Backbone = BOP.Backbone
$ = BOP.$
_ = BOP._

class BasicFetchObject extends BOP.BOPModel
  urlRoot: 'http://basicobject'

class BasicObject extends Backbone.Model

class TestObject extends BOP.BOPModel
  urlRoot: 'http://testobject'
  @has 'bo', BasicObject
  @has 'bfo', BasicFetchObject, method: 'fetch'

class TestCollection extends Backbone.Collection
  url: -> "http://testObject/#{@.test.id}/collection"
  model: TestObject

TestObject.has 'test_col', TestCollection, method: 'fetch', reverse: 'test'





describe 'has relationship function,', ->
  describe 'with parse relationship', ->

    it 'should add a relationship', ->
      to = new TestObject()
      to.has_relationship('bo').should.equal true
      to.get_relationship('bo').should.be.an 'object'
      to.get_relationship_model('bo').should.equal BasicObject
      to.get_relationship_method('bo').should.equal 'parse'
    
    it 'should initialize the related object on creation', (done) ->
      to = new TestObject({name: 'test', bo: {name: 'bo_test'}},{parse: true})
      $.when(to.get('name'), to.get('bo')).done( (name, bo) ->
        name.should.equal 'test'
        bo.should.be.an 'object'
        bo.should.be.instanceOf BasicObject
        bo.get('name').should.equal 'bo_test'
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        done()
      )

    it 'should initialize the reverse relationships', (done) ->
      to = new TestObject({name: 'test', bo: {name: 'bo_test'}}, {parse: true})
      $.when(to.get('name'), to.get('bo')).done( (name, bo) ->
        bo._parent.should.equal to
        bo._field_name.should.equal 'bo'
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        done()
      )

    it 'should serialize toJSON including the internal models', ->
      to_json = {name: 'test', bo: {name: 'bo_test'}}
      to = new TestObject( to_json , {parse: true} )
      to.toJSON().should.eql to_json

    it 'should create a model without a parse relationship', (done) ->
      to = new TestObject( {name: 'test'} , {parse: true} )
      $.when(to.get('name'), to.get('bo')).done( (name, bo) ->
        name.should.equal 'test'
        expect(bo).to.be.undefined
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        done()
      )

    it 'should save model including all parse relationship', (done) ->
      to_json = {name: 'test', id: 'new_id', bo: {name: 'bo_test'}}

      sinon.stub($, 'ajax', (req) -> 
        req.data.should.equal JSON.stringify(to_json)
        req.success(to_json, {}, {})
      )

      to = new TestObject(to_json, {parse: true})

      $.when(to.save()).done( (bo) ->
        to.id.should.equal 'new_id'
        sinon.assert.calledOnce($.ajax);
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        $.ajax.restore()
        done()
      )

  describe 'with fetch relationship', ->
    it 'should add the relationship', ->
      to = new TestObject()
      to.has_relationship('bfo').should.equal true
      to.get_relationship('bfo').should.be.an 'object'
      to.get_relationship_model('bfo').should.equal BasicFetchObject
      to.get_relationship_method('bfo').should.equal 'fetch'


    it 'should initialize the object relationship', (done) ->
      to = new TestObject({name: 'test', bfo: {name: 'bfo_test'}},{parse: true})
      $.when(to.get('name'), to.get('bfo'))
      .then((name, bfo) ->
        name.should.equal 'test'
        bfo.should.be.an 'object'
        bfo.should.be.instanceOf BasicFetchObject
        return bfo.get('name')
      )
      .done( (bfo_name) ->
        bfo_name.should.equal 'bfo_test'
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        done()
      )


    it 'should not be included in toJSON', ->
      to = new TestObject({name: 'test', bfo: {name: 'bfo_test'}},{parse: true})
      to.toJSON().should.eql {name: 'test'}

    it 'should not save the sub relationship', (done) ->
      #as it is another documnet
      to_json = {name: 'test', id: 'new_id', bfo: {name: 'bfo_test'}}

      sinon.stub($, 'ajax', (req) -> 
        req.data.should.equal JSON.stringify({name: 'test', id: 'new_id'})
        req.success(to_json, {}, {})
      )

      to = new TestObject(to_json,{parse: true})
      $.when(to.save()).done( (bo) ->
        to.id.should.equal 'new_id'
        sinon.assert.calledOnce($.ajax);
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        $.ajax.restore()
        done()
      )

    it 'should fetch on get', (done) ->
      sinon.stub($, 'ajax', (req) -> 
        req.url.should.equal 'http://basicobject'
        req.success({name: 'bfo_test', id: 'new_id'}, {}, {})
      )

      to = new TestObject({name: 'test'},{parse: true})
      $.when(to.get('bfo')).then( (bfo) ->
        bfo.id.should.equal 'new_id'
        return bfo.get('name')
      )
      .done( (name) ->
        name.should.equal 'bfo_test'
        sinon.assert.calledOnce($.ajax);
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        $.ajax.restore()
        done()
      )
    
    it 'should set the reverse relationship before fetching', (done) ->
      sinon.stub($, 'ajax', (req) -> 
        req.url.should.equal 'http://testObject/1/collection'
        req.success([{name: 'to_1'}, {name: 'to_2'} ], {}, {})
      )

      to = new TestObject({name: 'test', id: "1"},{parse: true})
      $.when(to.get('test_col')).then( (tcol) ->
        tcol.models.length.should.equal 2
        return tcol.models[0].get('name')
      )
      .done( (name) ->
        name.should.equal 'to_1'
        sinon.assert.calledOnce($.ajax);
      )
      .fail( -> 
        sinon.assert.fail()
      )
      .always( -> 
        $.ajax.restore()
        done()
      )
