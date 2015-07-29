{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'

SelectedMessageThreadsIdStore = require '../stores/selectedmessagethreadidstore'
actionTypes = require '../actions/actiontypes'

describe 'SelectedMessageThreadsIdStore', ->

  beforeEach ->
    @reactor = new Reactor
    @reactor.registerStores selectedThreadId: SelectedMessageThreadsIdStore

  describe '#setSelectedChannelId', ->

    it 'sets selected thread id to given channel id', ->

      @reactor.dispatch actionTypes.SET_SELECTED_MESSAGE_THREAD, messageId: '1'
      selectedId = @reactor.evaluate ['selectedThreadId']

      expect(selectedId).to.equal '1'

      @reactor.dispatch actionTypes.SET_SELECTED_MESSAGE_THREAD, messageId: '2'
      selectedId = @reactor.evaluate ['selectedThreadId']

      expect(selectedId).to.equal '2'



