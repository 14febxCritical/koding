{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'

SuggestionsQueryStore = require 'activity/flux/stores/suggestions/suggestionsquerystore'
actionTypes = require 'activity/flux//actions/actiontypes'

describe 'SuggestionsQueryStore', ->

  beforeEach ->

    @reactor = new Reactor
    @reactor.registerStores currentSuggestionsQuery : SuggestionsQueryStore


  describe '#setQuery', ->

    it 'sets current query to a given value', ->

      query1 = 'test query 1'
      query2 = 'test query 2'

      @reactor.dispatch actionTypes.SET_SUGGESTIONS_QUERY, query : query1
      query = @reactor.evaluate ['currentSuggestionsQuery']

      expect(query).to.equal query1

      @reactor.dispatch actionTypes.SET_SUGGESTIONS_QUERY, query: query2
      query = @reactor.evaluate ['currentSuggestionsQuery']

      expect(query).to.equal query2


