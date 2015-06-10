_                             = require 'lodash'
remote                        = require('app/remote').getInstance()
dateFormat                    = require 'dateformat'
sinkrow                       = require 'sinkrow'
globals                       = require 'globals'
kd                            = require 'kd'
KDNotificationView            = kd.NotificationView
nick                          = require 'app/util/nick'
getCollaborativeChannelPrefix = require 'app/util/getCollaborativeChannelPrefix'
showError                     = require 'app/util/showError'
whoami                        = require 'app/util/whoami'
RealtimeManager               = require './realtimemanager'
IDEChatView                   = require './views/chat/idechatview'
IDEMetrics                    = require './idemetrics'
doXhrRequest                  = require 'app/util/doXhrRequest'
realtimeHelpers               = require './collaboration/helpers/realtime'
socialHelpers                 = require './collaboration/helpers/social'
envHelpers                    = require './collaboration/helpers/environment'
CollaborationStateMachine     = require './collaboration/collaborationstatemachine'
environmentDataProvider       = require 'app/userenvironmentdataprovider'
isVideoFeatureEnabled         = require 'app/util/isVideoFeatureEnabled'

{warn} = kd

# Attn!!
#
# This object is designed to be a mixin for IDEAppController.
#
# @see `IDEAppController`

module.exports = CollaborationController =

  # social related

  setSocialChannel: (channel) ->

    @socialChannel = channel


  fetchSocialChannel: (callback) ->

    if @socialChannel
      return callback null, @socialChannel

    unless id = @getSocialChannelId()
      return callback()

    socialHelpers.fetchChannel id, (err, channel) =>
      return callback err  if err

      @setSocialChannel channel
      @bindSocialChannelEvents()
      callback null, @socialChannel


  getSocialChannelId: ->

    return @socialChannel?.id or @channelId or @workspaceData.channelId


  unsetSocialChannel: ->

    @channelId = @socialChannel = @workspaceData.channelId = null


  deletePrivateMessage: (callback = kd.noop) ->

    socialHelpers.destroyChannel @socialChannel, (err) =>
      return callback err  if err

      envHelpers.detachSocialChannel @workspaceData, (err) =>
        return callback err  if err
        @unsetSocialChannel()


  # FIXME: This method is called more than once. It should cache the result and
  # return if result set exists.
  listChatParticipants: (callback) ->

    id = @getSocialChannelId()

    socialHelpers.fetchParticipants id, (err, accounts) =>
      return throwError err  if err

      callback accounts


  getRealtimeFileName: (id) ->

    id or= @getSocialChannelId()

    unless id
      return showError 'social channel id is not provided'

    hostName = @getCollaborationHost()

    return "#{hostName}.#{id}"


  whenRealtimeReady: (callback) ->

    if @rtm?.isReady
    then callback()
    else @once 'RTMIsReady', callback


  kickParticipant: (account) ->

    return  unless @amIHost

    target = account.profile.nickname

    # this object is used to follow the same pattern as other
    # methods. IMO, it makes it easier to read. ~Umut
    callbacks =
      success: =>
        @broadcastMessage { target, type: 'ParticipantKicked' }
        @handleParticipantKicked target
      error: (err) ->
        # TODO: better error handling.
        showError err
        throwError err

    @removeWorkspaceSnapshot target

    @setMachineUser [target], no, (err) =>
      return callbacks.error err  if err
      socialHelpers.kickParticipants @socialChannel, [account], (err, result) =>
        return callbacks.error err  if err
        callbacks.success()


  handleParticipantKicked: (username) ->

    @chat.emit 'ParticipantLeft', username
    @statusBar.removeParticipantAvatar username
    @removeParticipantCursorWidget username
    # remove participant's all data persisted in realtime appInfo
    @removeParticipant username


  handleParticipantAction: (actionType, changeData) ->

    kd.utils.wait 2000, =>

      switch actionType
        when 'join' then @onRealtimeParticipantJoined changeData
        when 'left' then @onRealtimeParticipantLeft changeData


  onRealtimeParticipantJoined: (data) ->

    return  unless @stateMachine?.state is 'Active'

    {sessionId} = data.collaborator

    {targetUser} =
      realtimeHelpers.getTargetUser @participants, 'sessionId', sessionId

    unless targetUser
      return kd.warn 'Unknown user in collaboration, we should handle this case...'

    @chat.emit 'ParticipantJoined', targetUser
    @statusBar.emit 'ParticipantJoined', targetUser

    if @amIHost
      @ensureMachineShare [targetUser], (err) =>
        return throwError err  if err


  onRealtimeParticipantLeft: (data) ->

    return  unless @stateMachine?.state is 'Active'

    {sessionId} = data.collaborator

    {targetUser, targetIndex} =
      realtimeHelpers.getTargetUser @participants, 'sessionId', sessionId

    unless targetUser
      return kd.warn 'Unknown user in collaboration, we should handle this case...'

    @chat?.emit 'ParticipantLeft', targetUser
    @statusBar.emit 'ParticipantLeft', targetUser
    @removeParticipantCursorWidget targetUser

    realtimeHelpers.ensureParticipantLeft @participants, targetUser, targetIndex


  # realtime related stuff


  broadcastMessage: (options = {}) ->

    message = _.assign {}, options, { origin: nick() }
    @broadcastMessages.push message


  activateRealtimeManager: (doc) ->

    @rtm.setRealtimeDoc doc
    @bindRealtimeErrorEvents()

    @setCollaborativeReferences()
    @addParticipant whoami()
    @setWatchMap()
    @registerCollaborationSessionId()

    if @amIHost
    then @activateRealtimeManagerForHost()
    else @activateRealtimeManagerForParticipant()

    @rtm.isReady = yes
    @emit 'RTMIsReady'


  setWatchMap: ->

    return  if @myWatchMap.values().length

    @listChatParticipants (accounts) =>
      accounts.forEach (account) =>
        {nickname} = account.profile
        @myWatchMap.set nickname, nickname


  activateRealtimeManagerForHost: ->

    @getView().setClass 'host'
    @startHeartbeat()


  activateRealtimeManagerForParticipant: ->

    @startRealtimePolling()
    @resurrectSnapshot()

    if @permissions.get(nick()) is 'read'
      @makeReadOnly()


  setCollaborativeReferences: ->

    initialSnapshot = if @amIHost then @getWorkspaceSnapshot() else {}

    refs = realtimeHelpers.getReferences @rtm, @getSocialChannelId(), initialSnapshot

    # for backwards compatibility.
    # TODO: keep this until CollaborationModel abstraction. ~Umut
    @participants      = refs.participants
    @changes           = refs.changes
    @permissions       = refs.permissions
    @broadcastMessages = refs.broadcastMessages
    @myWatchMap        = refs.watchMap
    @mySnapshot        = refs.snapshot

    @rtm.once 'RealtimeManagerDidDispose', =>
      @participants      = null
      @changes           = null
      @permissions       = null
      @broadcastMessages = null
      @myWatchMap        = null
      @mySnapshot        = null


  registerCollaborationSessionId: ->

    realtimeHelpers.registerCollaborationSessionId @rtm, @participants


  addParticipant: (account) ->

    {hash, nickname} = account.profile

    val = {nickname, hash}
    index = @participants.indexOf val, (a, b) -> a.nickname is b.nickname
    @participants.push val  if index is -1


  watchParticipant: (nickname) -> @myWatchMap.set nickname, nickname


  unwatchParticipant: (nickname) -> @myWatchMap.delete nickname


  bindSocialChannelEvents: ->

    @socialChannel
      .on 'AddedToChannel', @bound 'participantAdded'
      .on 'ChannelDeleted', @bound 'stopCollaborationSession'
      .on 'MessageAdded', @bound 'channelMessageAdded'


  participantAdded: (participant) ->

    socialHelpers.fetchAccount participant, (err, account) =>

      return throwError err  if err
      return  unless account

      {nickname} = account.profile
      @statusBar.createParticipantAvatar nickname, no
      @watchParticipant nickname


  channelMessageAdded: (message) ->

    return  unless message.payload

    { systemType } = message.payload
    systemType   or= message.payload['system-message']

    if systemType is 'start'
      if @stateMachine.state is 'NotStarted'
        @stateMachine.transition 'Loading'


  bindRealtimeEvents: ->

    @rtm.on 'CollaboratorJoined', (doc, participant) =>
      return  unless @stateMachine.state is 'Active'
      @handleParticipantAction 'join', participant

    @rtm.on 'CollaboratorLeft', (doc, participant) =>
      return  unless @stateMachine.state is 'Active'
      @handleParticipantAction 'left', participant

    @rtm.on 'ValuesAddedToList', (list, event) =>
      [value] = event.values

      switch list
        when @changes           then @handleChange value
        when @broadcastMessages then @handleBroadcastMessage value

    @rtm.on 'ValuesRemovedFromList', (list, event) =>
      @handleChange event.values[0]  if list is @changes

    @rtm.on 'MapValueChanged', (map, event) =>
      if map is @myWatchMap
        @handleWatchMapChange event

      else if map is @permissions
        @handlePermissionMapChange event


  bindRealtimeErrorEvents: ->

    @on 'ErrorRealtimeFileMissing',   throwError
    @on 'ErrorRealtimeServer',        throwError
    @on 'ErrorRealtimeUserForbidden', throwError
    @on 'ErrorRealtimeTokenExpired',  throwError
    @on 'ErrorGoogleDriveApiClient',  throwError
    @on 'ErrorHappened',              throwError


  removeParticipant: (nickname) ->

    refs = { @participants, @permissions }

    realtimeHelpers.removeFromManager @rtm, refs, nickname


  setRealtimeManager: (object) ->

    callback = =>
      object.rtm = @rtm
      object.emit 'RealtimeManagerSet'

    @whenRealtimeReady callback


  isRealtimeSessionActive: (id, callback) ->

    title = @getRealtimeFileName id

    @rtm or= new RealtimeManager
    @rtm.ready => realtimeHelpers.isSessionActive @rtm, title, callback


  getCollaborationData: (callback = kd.noop) ->

    collaborationData =
      watchMap        : @myWatchMap?.values()
      amIHost         : @amIHost

    callback collaborationData


  startHeartbeat: ->

    interval = 1000 * 15
    @sendPing() # send the first ping
    @pingInterval = kd.utils.repeat interval, @bound 'sendPing'
    @on 'RealtimeManagerWillDispose', => kd.utils.killRepeat @pingInterval


  sendPing: ->

    {channelId} = @workspaceData

    doXhrRequest
      endPoint : '/api/social/collaboration/ping'
      type     : 'POST'
      async    : yes
      data:
        fileId    : @rtmFileId
        channelId : channelId
    , (err, response) ->

      return  if not err

      if err.code is 400
        kd.utils.killRepeat @pingInterval # graceful stop
        throwError "bad request, err: %s", err.message
      else
        throwError "#{err}: %s", JSON.stringify response


  startRealtimePolling: ->

    interval = 15 * 1000
    @pollInterval = kd.utils.repeat interval, @bound 'pollRealtimeDocument'


  pollRealtimeDocument: ->

    unless @rtm
      kd.utils.killRepeat @pollInterval
      return

    id = @getSocialChannelId()

    @isRealtimeSessionActive id, (isActive) =>

      return  if isActive

      kd.utils.killRepeat @pollInterval
      @showSessionEndedModal()


  handleBroadcastMessage: (data) ->

    {origin, type} = data

    if origin is nick()
      switch type
        when 'ParticipantKicked'
          return @handleParticipantKicked data.target
        else return

    switch type

      when 'SessionEnded'

        return  unless origin is @collaborationHost

        @showSessionEndedModal()

      when 'ParticipantWantsToLeave'

        @handleParticipantKicked data.origin

      when 'ParticipantKicked'

        return  unless data.origin is @collaborationHost

        if data.target is nick()
          @removeMachineNode()
          @showKickedModal()
        else
          @handleParticipantKicked data.target

      when 'SetMachineUser'

        return  if data.participants.indexOf(nick()) is -1

        @handleSharedMachine()


  handlePermissionMapChange: (event) ->

    @chat.settingsPane.emit 'PermissionChanged', event

    {property, newValue} = event

    return  unless property is nick()

    if      newValue is 'edit' then @makeEditable()
    else if newValue is 'read' then @makeReadOnly()


  handleWatchMapChange: (event) ->

    {property, newValue, oldValue} = event

    if newValue is property
      @statusBar.emit 'ParticipantWatched', property

    else unless newValue
      @statusBar.emit 'ParticipantUnwatched', property


  broadcastMachineUserChange: (participants, state) ->

    type = "#{if state then 'Set' else 'Unset'}MachineUser"

    @broadcastMessage {type, participants}


  handleSharedMachine: ->

    @unmountMachine @mountedMachine
    @mountedMachine.getBaseKite().reconnect()
    @mountMachine @mountedMachine


  resurrectSnapshot: ->

    return  if @fakeTabView

    snapshot = @mySnapshot.values().filter (item) -> not item.isInitial
    snapshot = @appendHostSnapshot snapshot  unless @amIHost

    @removeInitialViews()

    for change in snapshot when change.context
      @createPaneFromChange change

    @changeActiveTabView change?.context?.paneType


  appendHostSnapshot: (snapshot) ->

    if snapshot.length or @myWatchMap.values().length
      return snapshot

    key = "#{@collaborationHost}Snapshot"

    if hostSnapshot = @rtm.getFromModel(key)?.values()
      return snapshot.concat hostSnapshot


  showShareButton: ->

    @ready =>
      @statusBar.handleCollaborationLoading()
      @statusBar.share.show()


  collectButtonShownMetric: ->

    IDEMetrics.collect 'StatusBar.collaboration_button', 'shown'


  initCollaborationStateMachine: ->

    @stateMachine = new CollaborationStateMachine
      stateHandlers:
        Initial      : @bound 'onCollaborationInitial'
        Loading      : @bound 'onCollaborationLoading'
        Resuming     : @bound 'onCollaborationResuming'
        NotStarted   : @bound 'onCollaborationNotStarted'
        Preparing    : @bound 'onCollaborationPreparing'
        Prepared     : @bound 'onCollaborationPrepared'
        Creating     : @bound 'onCollaborationCreating'
        Active       : @bound 'onCollaborationActive'
        Ending       : @bound 'onCollaborationEnding'
        Created      : @bound 'onCollaborationCreated'


  onCollaborationInitial: ->

    if @mountedMachine.isMine()
      @showShareButton()

    kd.utils.defer => @stateMachine.transition 'Loading'


  onCollaborationLoading: ->

    @statusBar.emit 'CollaborationLoading'

    @checkSessionActivity
      active     : => @stateMachine.transition 'Resuming'
      notStarted : => @stateMachine.transition 'NotStarted'
      error      : => @stateMachine.transition 'ErrorLoading'


  checkSessionActivity: (callbacks) ->

    {channelId} = @workspaceData

    callMethod = (name, args...) -> callbacks[name] args...

    unless @workspaceData.channelId
      return callMethod 'notStarted'

    @fetchSocialChannel (err, channel) =>
      if err
        throwError err
        return callMethod 'notStarted'

      @isRealtimeSessionActive channel.id, (isActive, file) =>
        if isActive
        then callMethod 'active', channel, file
        else callMethod 'notStarted'


  onCollaborationNotStarted: ->

    @statusBar.emit 'CollaborationEnded'

    owned = @mountedMachine.isMine()
    approved = @mountedMachine.isApproved()

    if (not owned) and approved
      @statusBar.share.hide()

    @collectButtonShownMetric()


  prepareChatSession: (callbacks) ->

    socialHelpers.initChannel (err, channel) =>
      return callbacks.error err  if err

      @setSocialChannel channel
      @createChatPaneView channel

      envHelpers.updateWorkspace @workspaceData, { channelId : channel.id }
        .then =>
          @workspaceData.channelId = channel.id
          @chat.ready => callbacks.success()
        .error (err) => callbacks.error err


  onCollaborationPreparing: ->

    @prepareChatSession
      success : => @stateMachine.transition 'Prepared'
      error   : => @stateMachine.transition 'ErrorPreparing'


  onCollaborationPrepared: ->

    @chat.emit 'CollaborationNotInitialized'


  startCollaborationSession: ->

    switch @stateMachine.state
      when 'Prepared' then @stateMachine.transition 'Creating'


  onCollaborationCreating: ->

    @createCollaborationSession
      success : (doc) =>
        @whenRealtimeReady => @stateMachine.transition 'Created'
        @activateRealtimeManager doc
      error: =>
        @stateMachine.transition 'ErrorCreating'


  onCollaborationCreated: ->

    @chat.settingsPane.startSession.updateProgress 100

    kd.utils.wait 500, => @stateMachine.transition 'Active'


  createCollaborationSession: (callbacks) ->

    fileName = @getRealtimeFileName()

    realtimeHelpers.createCollaborationFile @rtm, fileName, (err, file) =>
      return callbacks.error err  if err

      realtimeHelpers.loadCollaborationFile @rtm, file.id, (err, doc) =>
        return callbacks.error err  if err

        @rtmFileId = file.id

        socialHelpers.sendActivationMessage @socialChannel, kd.noop

        @setMachineSharingStatus on, (err) =>
          return callbacks.error err  if err
          callbacks.success doc


  onCollaborationResuming: ->

    @showShareButton()

    successCb = (channel, doc) =>
      @whenRealtimeReady =>
        @setSocialChannel channel
        @createChatPaneView channel
        @chat.ready => @stateMachine.transition 'Active'

      @activateRealtimeManager doc

    errorCb = => # @stateMachine.transition 'ErrorResuming'

    @resumeCollaborationSession
      success : successCb
      error   : errorCb


  resumeCollaborationSession: (callbacks) ->

    title = @getRealtimeFileName()
    realtimeHelpers.fetchCollaborationFile @rtm, title, (err, file) =>
      return callbacks.error err  if err
      realtimeHelpers.loadCollaborationFile @rtm, file.id, (err, doc) =>
        return callbacks.error err  if err
        @rtmFileId = file.id
        callbacks.success @socialChannel, doc


  onCollaborationActive: ->

    @showChatPane()

    @transitionViewsToActive()
    @collectButtonShownMetric()
    @bindRealtimeEvents()

    # this method comes from VideoCollaborationController.
    # It's mixed into IDEAppController after CollaborationController.
    # This is probably an anti pattern, we need to look into this again. ~Umut
    @prepareVideoCollaboration()

    # attach RTM instance to already in-screen panes.
    @forEachSubViewInIDEViews_ @bound 'setRealtimeManager'

    # attach realtime manager when a new editor pane is opened.
    @on 'EditorPaneDidOpen', @bound 'setRealtimeManager'

    @updateWorkspaceSnapshotModel()

    @on 'SetMachineUser', @bound 'broadcastMachineUserChange'


  transitionViewsToActive: ->

    @listChatParticipants (accounts) =>
      @chat.settingsPane.createParticipantsList accounts

    {settingsPane} = @chat
    settingsPane.on 'ParticipantKicked', @bound 'handleParticipantKicked'
    settingsPane.updateDefaultPermissions()

    @chat.emit 'CollaborationStarted'
    @statusBar.emit 'CollaborationStarted'

    { onboarding } = kd.singletons
    onboarding.run 'CollaborationStarted'
    @chat.on ['ViewBecameHidden', 'ViewBecameVisible'], ->
      onboarding.refresh 'CollaborationStarted'


  onCollaborationEnding: ->

    @chat.settingsPane.endSession.disable()

    @off 'SetMachineUser'

    if @amIHost
      @endCollaborationForHost =>
        @modal?.destroy()
        @handleCollaborationEndedForHost()
    else
      @endCollaborationForParticipant =>
        @modal?.destroy()
        @handleCollaborationEndedForParticipant()

    kd.singletons.onboarding.stop 'CollaborationStarted'


  endCollaborationForHost: (callback) ->

    @broadcastMessage { type: 'SessionEnded' }

    fileName = @getRealtimeFileName()

    realtimeHelpers.deleteCollaborationFile @rtm, fileName, (err) =>
      throwError err  if err

    @setMachineSharingStatus off, (err) =>
      throwError err  if err

    socialHelpers.destroyChannel @socialChannel, (err) =>
      throwError err  if err

    envHelpers.detachSocialChannel @workspaceData, (err) =>
      throwError err  if err

    @unsetSocialChannel()
    callback()


  handleCollaborationEndedForHost: ->

    return  unless @stateMachine.state in ['Ending']

    @rtm.once 'RealtimeManagerWillDispose', =>
      @chat.emit 'CollaborationEnded'
      @chat.destroy()
      @chat = null
      @statusBar.emit 'CollaborationEnded'

    @rtm.once 'RealtimeManagerDidDispose', =>
      kd.utils.defer @bound 'prepareCollaboration'

    @cleanupCollaboration()


  endCollaborationForParticipant: (callback) ->

    socialHelpers.leaveChannel @socialChannel, (err) =>
      throwError err  if err

    @removeWorkspaceSnapshot()

    @setMachineUser [nick()], no, (err) =>
      throwError err  if err
      @broadcastMessage type: 'ParticipantWantsToLeave'

    callback()


  handleCollaborationEndedForParticipant: ->

    # TODO: fix explicit state checks.
    return  unless @stateMachine.state in ['Active', 'Ending']

    # TODO: fix implicit emit.
    @rtm.once 'RealtimeManagerWillDispose', =>
      @chat.emit 'CollaborationEnded'
      @chat.destroy()
      @chat = null
      @statusBar.emit 'CollaborationEnded'
      @removeParticipant nick()
      @removeMachineNode()

    @rtm.once 'RealtimeManagerDidDispose', =>
      kd.utils.defer @bound 'quit'

    @cleanupCollaboration()


  showChat: ->

    switch @stateMachine.state
      when 'Active'     then @showChatPane()
      when 'Prepared'   then @chat.show()
      when 'NotStarted' then @stateMachine.transition 'Preparing'


  stopCollaborationSession: ->

    return  unless @stateMachine

    switch @stateMachine.state
      when 'Active' then @stateMachine.transition 'Ending'


  showChatPane: ->

    @chat.showChatPane()
    @chat.start()


  createChatPaneView: (channel) ->
    return throwError 'RealtimeManager is not set'  unless @rtm

    @chat = new IDEChatView { @rtm, @isInSession }, channel
    @getView().addSubView @chat


  prepareCollaboration: ->

    @rtm = new RealtimeManager

    @rtm.ready @bound 'initCollaborationStateMachine'


  getCollaborationHost: -> if @amIHost then nick() else @collaborationHost


  cleanupCollaboration: (options = {}) ->

    # TODO: remove Active session from here,
    # we will deffo need a leaving state.
    return  unless @stateMachine.state in ['Ending', 'Active']

    @rtm.once 'RealtimeManagerWillDispose', =>
      kd.utils.killRepeat @pingInterval
      kd.singletons.mainView.activitySidebar.emit 'ReloadMessagesRequested'

    @rtm.once 'RealtimeManagerDidDispose', =>
      @rtm = null
      delete @stateMachine

    @rtm.dispose()
    @emit 'CollaborationDidCleanup'


  # environment related


  removeMachineNode: ->

    kd.singletons.mainView.activitySidebar.removeMachineNode @mountedMachine
    environmentDataProvider.removeCollaborationMachine @mountedMachine


  ensureMachineShare: (usernames, callback) ->

    {fetchMissingParticipants} = envHelpers

    fetchMissingParticipants @mountedMachine, usernames, (err, missing) =>
      return callback err  if err

      @setMachineUser missing, yes, callback


  setMachineSharingStatus: (status, callback) ->

    getUsernames = (accounts) ->

      accounts
        .map ({profile: {nickname}}) -> nickname
        .filter (nickname) -> nickname isnt nick()

    if @amIHost
      @listChatParticipants (accounts) =>
        usernames = getUsernames accounts
        @setMachineUser usernames, status, callback
    else
      @setMachineUser [nick()], status, callback


  setMachineUser: (usernames, share = yes, callback = kd.noop) ->

    # TODO: needs an investigation here.
    # if this usernames length check would be done
    # via helper method, the broadcastMessage
    # lines would be executed as well. attn to @szkl.
    return callback null  unless usernames.length

    {setMachineUser} = envHelpers

    setMachineUser @mountedMachine, usernames, share, (err) =>
      return callback err  if err

      @emit 'SetMachineUser', usernames, share

      callback null


  # collab related modals (should be its own mixin)


  showEndCollaborationModal: (callback) ->

    modalOptions =
      title      : 'Are you sure?'
      content    : 'This will end your session and all participants will be removed from this session.'

    @showModal modalOptions, => @stopCollaborationSession callback


  showKickedModal: ->
    options        =
      title        : 'Your session has been closed'
      content      : "You have been removed from the session by @#{@collaborationHost}."
      blocking     : yes
      buttons      :
        ok         :
          title    : 'OK'
          style    : 'solid green medium'
          callback : =>
            @modal.destroy()

    @chat?.end()
    @showModal options
    @handleCollaborationEndedForParticipant()


  showSessionEndedModal: (content) ->

    content ?= "This collaboration session has been terminated by the host @#{@collaborationHost}."

    options        =
      title        : 'Session ended'
      content      : content
      blocking     : yes
      buttons      :
        quit       :
          style    : 'solid light-gray medium'
          title    : 'LEAVE'
          callback : =>
            @modal.destroy()

    @chat?.end()
    @showModal options
    @handleCollaborationEndedForParticipant()


  handleParticipantLeaveAction: ->

    options   =
      title   : 'Are you sure?'
      content : "If you leave this session you won't be able to return back."

    @showModal options, => @stateMachine.transition 'Ending'


  throwError: throwError = (err, args...) ->

    format = JSON.stringify \
      switch typeof err
        when 'string' then err
        when 'object' then err.message or err.description
        else args.join ' '

    argIndex = 0
    console.error """
      IDE.CollaborationController:
      #{ format.replace /%s/g, -> JSON.stringify(args[argIndex++]) or '%s' }
    """


  onWorkspaceChannelChanged: ->

    {channelId} = @workspaceData

    if channelId and typeof channelId is 'string' and channelId.length
      if @stateMachine.state is 'NotStarted'
        @stateMachine.transition 'Loading'
    else
      if @stateMachine.state is 'Active'
        @stateMachine.transition 'Ending'


  updateWorkspaceSnapshotModel: ->

    for hash, change of @getWorkspaceSnapshot()
      @mySnapshot.set hash, change
