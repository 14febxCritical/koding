VideoCollaborationModel = require 'app/videocollaboration/model'
socialHelpers           = require './collaboration/helpers/social'
isVideoFeatureEnabled   = require 'app/util/isVideoFeatureEnabled'

generatePayloadFromModel = (model) ->
  return {
    activeParticipant   : model.getActiveParticipant()
    selectedParticipant : model.getSelectedParticipant()
    participants        : model.getParticipants()
  }

module.exports = VideoCollaborationController =

  prepareVideoCollaboration: ->

    @videoModel = new VideoCollaborationModel
      channel : @socialChannel
      view    : @chat.getVideoView()

    @videoModel
      .on 'SessionConnected',              @bound 'handleVideoSessionConnected'
      .on 'CameraAccessQuestionAsked',     @bound 'handleVideoAccessQuestionAsked'
      .on 'CameraAccessQuestionAnswered',  @bound 'handleVideoAccessQuestionAnswered'
      .on 'VideoCollaborationActive',      @bound 'handleVideoActive'
      .on 'VideoCollaborationEnded',       @bound 'handleVideoEnded'
      # .on 'ParticipantConnected',          @bound 'handleVideoParticipantConnected'
      # .on 'ParticipantDisconnected',       @bound 'handleVideoParticipantDisconnected'
      # .on 'ParticipantJoined',             @bound 'handleVideoParticipantJoined'
      # .on 'ParticipantLeft',               @bound 'handleVideoParticipantLeft'
      .on 'ActiveParticipantChanged',      @bound 'handleVideoActiveParticipantChanged'
      .on 'SelectedParticipantChanged',    @bound 'handleVideoSelectedParticipantChanged'
      .on 'ParticipantAudioStateChanged',  @bound 'handleVideoParticipantAudioStateChanged'
      .on 'ParticipantCameraStateChanged', @bound 'handleVideoParticipantCameraStateChanged'
      .on 'ParticipantStartedTalking', (participant) =>
        @handleVideoParticipantTalkingStateChanged participant, on
      .on 'ParticipantStoppedTalking', (participant) =>
        @handleVideoParticipantTalkingStateChanged participant, off

    participantEvents = [
      'SelectedParticipantChanged'
      'ParticipantConnected'
      'ParticipantJoined'
      'ParticipantLeft'
      'ParticipantDisconnected'
    ]

    @videoModel.on participantEvents, @bound 'handleVideoParticipantAction'

    @on 'CollaborationDidCleanup', =>
      @videoModel.session.disconnect()


  fetchVideoParticipants: (callback) ->

    callback @videoModel.getParticipants()


  startVideoCollaboration: -> @videoModel.start()


  endVideoCollaboration: -> @videoModel.end()


  muteParticipant: (nickname) -> @videoModel.muteParticipant nickname


  toggleVideoControl: (type, activeState) ->

    switch type
      when 'audio'   then @videoModel.requestAudioStateChange activeState
      when 'video'   then @videoModel.requestVideoStateChange activeState
      when 'speaker' then @videoModel.requestSpeakerStateChange activeState
      when 'end'     then @endVideoCollaboration()


  switchToUserVideo: (nickname) ->

    @videoModel.changeSelectedParticipant nickname


  hasParticipantWithAudio: (nickname, callback) ->

    @videoModel.hasParticipantWithAudio nickname, callback


  handleVideoSessionConnected: (session, videoActive) ->

    if isVideoFeatureEnabled()
      if videoActive
        @emitToViews 'VideoSessionConnected', { action: 'join' }
      else
        if @amIHost
          @emitToViews 'VideoSessionConnected', { action: 'start' }


  handleVideoAccessQuestionAsked: ->


  handleVideoAccessQuestionAnswered: ->


  handleVideoEnded: ->
    @emitToViews 'VideoCollaborationEnded'


  handleVideoActive: (publisher) ->
    @emitToViews 'VideoCollaborationActive'


  handleVideoParticipantAction: ->

    payload = generatePayloadFromModel @videoModel
    @emitToViews 'VideoParticipantsDidChange', payload


  handleVideoParticipantConnected: (participant) ->
    @emitToViews 'VideoParticipantDidConnect', participant


  handleVideoParticipantDisconnected: (participant) ->
    @emitToViews 'VideoParticipantDidDisconnect', participant


  handleVideoParticipantJoined: (participant) ->
    @emitToViews 'VideoParticipantDidJoin', participant


  handleVideoParticipantLeft: (participant) ->
    @emitToViews 'VideoParticipantDidLeave', participant


  handleVideoSelectedParticipantChanged: (nickname, isOnline) ->

    unless nickname
      @emitToViews 'VideoSelectedParticipantDidChange', null, null, isOnline
      return

    socialHelpers.fetchAccount nickname, (err, account) =>
      return console.error err  if err
      @emitToViews 'VideoSelectedParticipantDidChange', nickname, account, isOnline


  handleVideoActiveParticipantChanged: (nickname) ->
    socialHelpers.fetchAccount nickname, (err, account) =>
      return console.error err  if err
      @emitToViews 'VideoActiveParticipantDidChange', nickname, account


  handleVideoParticipantAudioStateChanged: (participant, state) ->
    @emitToViews 'VideoParticipantAudioStateDidChange', participant


  handleVideoParticipantCameraStateChanged: (participant, state) ->
    @emitToViews 'VideoParticipantCameraStateDidChange', participant


  handleVideoParticipantTalkingStateChanged: (participant, state) ->
    @emitToViews 'VideoParticipantTalkingStateDidChange', participant, state


  emitToViews: (args...) ->
    @statusBar?.emit args...
    @chat?.emit args...


