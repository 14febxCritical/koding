{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'

ChannelParticipantsDropdownVisibilityStore = require 'activity/flux/stores/channelparticipants/channelparticipantsdropdownvisibilitystore'
actions = require 'activity/flux/actions/actiontypes'

describe 'ChannelParticipantsDropdownVisibilityStore', ->

  beforeEach ->

    @reactor = new Reactor
    @reactor.registerStores channelParticipantsDropdownVisibility : ChannelParticipantsDropdownVisibilityStore


  describe '#setVisibility', ->

    it 'sets visibility', ->

      @reactor.dispatch actions.SET_CHANNEL_PARTICIPANTS_DROPDOWN_VISIBILITY, { visible : yes }
      visible = @reactor.evaluate ['channelParticipantsDropdownVisibility']

      expect(visible).to.be.true

      @reactor.dispatch actions.SET_CHANNEL_PARTICIPANTS_DROPDOWN_VISIBILITY, { visible : no }
      visible = @reactor.evaluate ['channelParticipantsDropdownVisibility']

      expect(visible).to.be.false

