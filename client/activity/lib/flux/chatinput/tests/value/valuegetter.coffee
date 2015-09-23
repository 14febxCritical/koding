{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'
ChatInputValueStore = require 'activity/flux/chatinput/stores/valuestore'
SelectedChannelThreadIdStore = require 'activity/flux/stores/selectedchannelthreadidstore'
ChatInputFlux = require 'activity/flux/chatinput'
ActivityActions = require 'activity/flux/actions/actiontypes'
ChatInputActions = require 'activity/flux/chatinput/actions/actiontypes'

describe 'ChatInputValueGetter', ->

  beforeEach ->

    @reactor = new Reactor()
    stores = {}
    stores[ChatInputValueStore.getterPath] = ChatInputValueStore
    stores[SelectedChannelThreadIdStore.getterPath] = SelectedChannelThreadIdStore
    @reactor.registerStores stores


  describe '#currentValue', ->

    channelId1  = 'channel1'
    channelId2  = 'channel2'
    value1      = '12345'
    value2      = 'qwerty'
    { getters } = ChatInputFlux

    it 'gets value depending on the current channel id', ->

      @reactor.dispatch ChatInputActions.SET_CHAT_INPUT_VALUE, { channelId : channelId1, value : value1 }
      @reactor.dispatch ChatInputActions.SET_CHAT_INPUT_VALUE, { channelId : channelId2, value : value2 }

      @reactor.dispatch ActivityActions.SET_SELECTED_CHANNEL_THREAD, { channelId : channelId1 }

      value = @reactor.evaluate getters.currentValue
      expect(value).to.equal value1

      @reactor.dispatch ActivityActions.SET_SELECTED_CHANNEL_THREAD, { channelId : channelId2 }

      value = @reactor.evaluate getters.currentValue
      expect(value).to.equal value2

