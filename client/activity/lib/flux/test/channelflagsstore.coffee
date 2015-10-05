{ expect }               = require 'chai'
Reactor                  = require 'app/flux/reactor'
actionTypes              = require '../actions/actiontypes'
ChannelFlagsStore        = require '../stores/channelflagsstore'


describe 'ChannelFlagsStore', ->

  beforeEach ->
    @reactor = new Reactor
    @reactor.registerStores [ChannelFlagsStore]

  afterEach -> @reactor.reset()

  describe 'handleLoadMessagesBegin', ->

    it 'listens to regular load messages success', ->

      @reactor.dispatch actionTypes.LOAD_MESSAGES_BEGIN, {
        channelId: 'mockChannelFlagsForBeginId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']

      expect(storeState.mockChannelFlagsForBeginId.isMessagesLoading).to.eql yes


  describe 'handleLoadMessagesSuccess', ->

    it 'listens to regular load messages success', ->

      @reactor.dispatch actionTypes.LOAD_MESSAGES_SUCCESS, {
        channelId: 'mockChannelFlagsForSuccessId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']

      expect(storeState.mockChannelFlagsForSuccessId.isMessagesLoading).to.eql no


  describe 'handleCreateMessageBegin', ->

    it 'sets isMessageBeingSubmitted flag to true when a new message is being submitted in the channel', ->

      @reactor.dispatch actionTypes.CREATE_MESSAGE_BEGIN, {
        channelId: 'mockChannelFlagsForBeginId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']

      expect(storeState.mockChannelFlagsForBeginId.isMessageBeingSubmitted).to.eql yes


  describe 'handleCreateMessageEnd', ->

    it 'sets isMessageBeingSubmitted flag to false when a new message has been successfully submitted', ->

      @reactor.dispatch actionTypes.CREATE_MESSAGE_BEGIN, {
        channelId: 'mockChannelFlagsForEndId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']
      expect(storeState.mockChannelFlagsForEndId.isMessageBeingSubmitted).to.eql yes

      @reactor.dispatch actionTypes.CREATE_MESSAGE_SUCCESS, {
        channelId: 'mockChannelFlagsForEndId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']
      expect(storeState.mockChannelFlagsForEndId.isMessageBeingSubmitted).to.eql no


    it 'sets isMessageBeingSubmitted flag to false when a new message has failed to submit', ->

      @reactor.dispatch actionTypes.CREATE_MESSAGE_BEGIN, {
        channelId: 'mockChannelFlagsForEndId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']
      expect(storeState.mockChannelFlagsForEndId.isMessageBeingSubmitted).to.eql yes

      @reactor.dispatch actionTypes.CREATE_MESSAGE_FAIL, {
        channelId: 'mockChannelFlagsForEndId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']
      expect(storeState.mockChannelFlagsForEndId.isMessageBeingSubmitted).to.eql no


  describe 'handleSetAllMessagesLoaded', ->

    it 'sets reachedFirstMessage flags to true', ->

      @reactor.dispatch actionTypes.SET_ALL_MESSAGES_LOADED, {
        channelId: 'mockChannelFlagsForSuccessId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']

      expect(storeState.mockChannelFlagsForSuccessId.reachedFirstMessage).to.eql yes


  describe 'handleUnsetAllMessagesLoaded', ->

    it 'sets reachedFirstMessage flags to false', ->

      @reactor.dispatch actionTypes.UNSET_ALL_MESSAGES_LOADED, {
        channelId: 'mockChannelFlagsForSuccessId'
      }

      storeState = @reactor.evaluateToJS ['ChannelFlagsStore']

      expect(storeState.mockChannelFlagsForSuccessId.reachedFirstMessage).to.eql no

