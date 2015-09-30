{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'

ChatInputCommandsSelectedIndexStore = require 'activity/flux/chatinput/stores/command/selectedindexstore'
actions = require 'activity/flux/chatinput/actions/actiontypes'

describe 'ChatInputCommandsSelectedIndexStore', ->

  beforeEach ->

    @reactor = new Reactor
    @reactor.registerStores chatInputCommandsSelectedIndex : ChatInputCommandsSelectedIndexStore


  describe '#setIndex', ->

    it 'sets selected index', ->

      index = 1
      stateId = 'test'

      @reactor.dispatch actions.SET_CHAT_INPUT_COMMANDS_SELECTED_INDEX, { stateId, index }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal index


  describe '#moveToNextIndex', ->

  	it 'moves to next index', ->

      index = 1
      nextIndex = index + 1
      stateId = 'test'

      @reactor.dispatch actions.SET_CHAT_INPUT_COMMANDS_SELECTED_INDEX, { index, stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal index
      
      @reactor.dispatch actions.MOVE_TO_NEXT_CHAT_INPUT_COMMANDS_INDEX, { stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal nextIndex


  describe '#moveToPrevIndex', ->

    it 'moves to prev index', ->

      index = 1
      prevIndex = index - 1
      stateId = 'test'

      @reactor.dispatch actions.SET_CHAT_INPUT_COMMANDS_SELECTED_INDEX, { index, stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal index
      
      @reactor.dispatch actions.MOVE_TO_PREV_CHAT_INPUT_COMMANDS_INDEX, { stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal prevIndex


  describe '#resetIndex', ->

    it 'resets selected index', ->

      index = 2
      stateId = 'test'

      @reactor.dispatch actions.SET_CHAT_INPUT_COMMANDS_SELECTED_INDEX, { index, stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.equal index

      @reactor.dispatch actions.RESET_CHAT_INPUT_COMMANDS_SELECTED_INDEX, { stateId }
      selectedIndex = @reactor.evaluate(['chatInputCommandsSelectedIndex']).get stateId

      expect(selectedIndex).to.be.undefined

