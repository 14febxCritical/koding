class KiteController extends KDController

  _tempOptions   = null
  _tempCallback  = null
  _attempt       = 1
  _notifications =
    default           : "Something went wrong"
    creatingEnv       : "Creating your environment."
    stillCreatingEnv  : "...still busy with setting up your environment."
    creationTookLong  : "...still busy with it, there might be something wrong."
    tookTooLong       : "It seems like we couldn't set up your environment, please click here to try again."
    envCreated        : "Your server, terminal and files are ready, enjoy!"
    notResponding     : "Backend is not responding, trying to fix..."
    checkingServers   : "Checking if servers are back..."
    alive             : "Shared hosting is alive!"

  getKiteKey =(kiteName, correlationName)->
    "~#{kiteName}~#{correlationName}"

  getKite:(kiteName, correlationName)->
    key = getKiteKey kiteName, correlationName
    kite = @kiteInstances[key]
    return kite  if kite?
    kite = @createKite kiteName, correlationName, key
    @kiteInstances[key] = kite
    return kite

  destroyKite:(kite)->
    delete @kiteInstances[kite.kiteKey]

  createKite:(kiteName, correlationName, kiteKey)->
    kite = new Kite { kiteName, correlationName, kiteKey }
    kite.on 'destroy', => @destroyKite kite
    return kite

  # notification = null
  notify = (options = {})->

    # notification.destroy() if notification
    if "string" is typeof options
      options = msg : options

    options.msg      or= _notifications.default
    options.duration or= 3303
    options.cssClass or= ""
    options.click    or= noop

    notification = new KDNotificationView
      title     : "<span></span>#{options.msg}"
      type      : "tray"
      cssClass  : "mini realtime #{options.cssClass}"
      duration  : options.duration
      click     : options.click

  constructor:->

    super

    @kiteIds   = {}
    @status    = no
    @intervals = {}
    @setListeners()
    @kites     = {}
    @channels  = {}

    # new API:
    @kiteInstances = {}


  addKite: (name, channel) ->
    @channels[name] = channel
    @kites[name] = channel
    @emit "channelAdded", channel, name

  deleteKite: (name) ->
    @emit "channelDeleted", @kites[name], name
    delete @kites[name]
    delete @channels[name]

  run:(options = {}, callback)->

    if "string" is typeof options
      command = options
      options = {}

    currentGroupName = (KD.getSingleton 'groupsController').getGroupSlug()

    options.kiteName or= "os"
    options.method   or= "exec"
    # options.correlationName or= currentGroupName

    vmName = if options.vmName then options.vmName \
             else if not currentGroupName or currentGroupName is 'koding'
             then KD.whoami().profile.nickname
             else currentGroupName

    kite = @getKite options.kiteName, vmName

    if command
      options.withArgs = command
    else
      options.withArgs or= {}

    notify "Calling <b>#{options.method}</b> method, from <b>#{options.kiteName}</b> kite"
    log "Kite Request:", options

    kite.tell options, (err, response)=>
      @parseKiteResponse {err, response}, options, callback

  setListeners:->

    mainController = @getSingleton "mainController"

    @on "CreatingUserEnvironment", =>
      mainView = @getSingleton "mainView"
      mainView.contentPanel.putOverlay
        isRemovable : no
        cssClass    : "dummy"
        animated    : yes
        parent      : ".application-page.start-tab"

    @on "UserEnvironmentIsCreated", =>
      return if _attempt is 1
      notify _notifications.envCreated
      mainView = @getSingleton "mainView"
      mainView.removeOverlay()
      mainView.contentPanel.removeOverlay()
      _attempt = 1

  accountChanged:(account)->

    kiteName = "sharedHosting"
    if KD.isLoggedIn()
      @resetKiteIds kiteName, (err, res)=>
        unless err
          @status = yes
    else
      @status = no


  parseKiteResponse:({err, response}, options, callback)->

    if err and response
      callback? err, response
      warn "Command failed:", err
    else if err
      if err.code is 503
        notification = notify
          msg         : error.message
          duration    : 0
          click       : -> notification.destroy()
      else if err.kiteNotPresent
        @handleKiteNotPresent {err, response}, options, callback
      else if /No\ssuch\suser/.test err
        _tempOptions  or= options
        _tempCallback or= callback
        @createSystemUser callback
      else if /Entry\sAlready\sExists/.test err
        @utils.wait 5000, =>
          _attempt++
          @run _tempOptions, _tempCallback
      else if err.message?
        callback? err
        warn "An error occured:", err.message
      else
        callback? err
        warn "parsing kite response: we dont handle this yet", err
    else
      @status = yes
      callback? err, response

  handleKiteNotPresent:({err, response}, options, callback)->

    # log "handleKiteNotPresent"
    notify _notifications.notResponding
    @resetKiteIds options.kiteName, (err, kiteIds)=>
      if Array.isArray(kiteIds) and kiteIds.length > 0
        # warn kiteIds, ">>>>>"
        @run options, callback
      else
        notify "Backend is not responding, try again later."
        warn "handleKiteNotPresent: we dont handle this yet", err
        callback? "handleKiteNotPresent: we dont handle this yet"

  createSystemUser:(callback)->

    if _attempt > 1 and _attempt < 5
      notify _notifications.stillCreatingEnv
    else if _attempt >= 5 and _attempt < 10
      notify
        msg       : _notifications.creationTookLong
        duration  : 4500
    else if _attempt >= 10
      notify
        msg       : _notifications.tookTooLong
        duration  : 0
        click     : => @createSystemUser callback
      return
    else
      @emit "CreatingUserEnvironment"
      notify _notifications.creatingEnv

    @run
      method     : "createSystemUser"
      withArgs   :
        fullName : "#{KD.whoami().getAt 'profile.firstName'} #{KD.whoami().getAt 'profile.lastName'}"
        password : __utils.getRandomHex().substr(1)
    , (err, res)=>
      # this callback gets lost
      log "Creating the user environment."
      callback? err, res
      unless err
        notify _notifications.envCreated
        @emit "UserEnvironmentIsCreated"
      else
        error "createUserEnvironment", err

  ping:(kiteName, callback)->

    log "pinging : #{kiteName}"
    @run method : "_ping", (err, res)=>
      unless err
        @status = yes
        clearInterval @pinger if @pinger
        notify _notifications.alive

      else
        notify _notifications.checkingServers
        @parseError @, err
      callback?()

  setPinger:->

    return if @pinger
    @pinger = setInterval =>
      @ping()
    , 10000
    @ping()

  resetKiteIds:(kiteName = "sharedHosting", callback)->
#
#    KD.whoami().fetchKiteIds {kiteName}, (err,kiteIds)=>
#      if err
#        notify "Backend is not responding, trying to fix..."
#      else
#        notify "Backend servers are ready."
#        @kiteIds[kiteName] = kiteIds
#      callback err, kiteIds
#

