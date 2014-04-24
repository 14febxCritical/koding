class KodingKite_OsKite extends KodingKite_VmKite

  @constructors['oskite'] = this

  @createApiMapping
    exec            : 'exec'

    appInstall      : 'app.install'
    appDownload     : 'app.download'
    appPublish      : 'app.publish'
    appSkeleton     : 'app.skeleton'

    fsReadDirectory : 'fs.readDirectory'
    fsGlob          : 'fs.glob'
    fsReadFile      : 'fs.readFile'
    fsGetInfo       : 'fs.getInfo'
    fsSetPermissions: 'fs.setPermissions'
    fsRemove        : 'fs.remove'

    fsUniquePath    : 'fs.uniquePath'
    fsWriteFile     : 'fs.writeFile'
    fsRename        : 'fs.rename'
    fsCreateDirectory: 'fs.createDirectory'

    s3Store         : 's3.store'
    s3Delete        : 's3.delete'

    vmStart         : 'vm.start'
    vmPrepareAndStart: 'vm.prepareAndStart'
    vmStopAndUnprepare: 'vm.stopAndUnprepare'
    vmShutdown      : 'vm.shutdown'
    vmUnprepare     : 'vm.unprepare'
    vmStop          : 'vm.stop'
    vmReinitialize  : 'vm.reinitialize'
    vmInfo          : 'vm.info'
    vmResizeDisk    : 'vm.resizeDisk'
    vmCreateSnapshot: 'vm.createSnapshot'

  constructor: (options = {}, data) ->
    super options, data
    @pollState()

  stopPollingState: ->
    log 'stop polling state'
    KD.utils.killRepeat @intervalId
    @intervalId = null

  pollState: ->
    log 'start polling state'
    @fetchState()

    KD.getSingleton('mainController')
      .once('userIdle', @bound 'stopPollingState')
      .once('userBack', @bound 'pollState')

    @intervalId = KD.utils.repeat KD.config.osKitePollingMs, @bound 'fetchState'

  fetchState: ->
    @vmInfo().then (state) =>
      @emit 'vmOn'  if state.state is 'RUNNING' and
                       @recentState?.state isnt 'RUNNING'
      @recentState = state
      @emit 'vm.state.info', @recentState

  changeState: (state, event, finEvent, method) ->
    if not @recentState? or @recentState.state isnt state
      method.call this, onProgress: (update) =>
        return @handleError update  if update.error
        if update.message is 'FINISHED'
          @recentState?.state = state
          @emit finEvent
        @emit event, update
    else
      Promise.resolve()

  vmOn: (t = 0) ->
    @changeState 'RUNNING', 'vm.progress.start', 'vmOn', @vmPrepareAndStart
      .catch (err) =>
        if t < 10
          return Promise.delay(Math.pow 0.7, ++t).then => @vmOn t
        throw err

  vmOff: ->
    @changeState 'STOPPED', 'vm.progress.stop', 'vmOff', @vmStopAndUnprepare

  fsExists: (options) ->
    @fsGetInfo(options).then (result) -> return !!result

  handleError: (update) ->
    {error} = update
    warn "vm prepare error ", error.Message
    @recentState?.state = 'FAILED'
    @emit 'vm.progress.error', error
