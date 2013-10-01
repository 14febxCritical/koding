# √ uncomplicate this - Sinan 7/2012
# √ rewriting this - Sinan 2/2013

class ApplicationManager extends KDObject

  manifestsFetched = no

  ###

  * EMITTED EVENTS
    - AppCreated                  [appController]
    - AppManagerWantsToShowAnApp  [appController, appView, appOptions]
  ###

  constructor:->

    super

    @appControllers = {}
    @frontApp       = null
    @defaultApps    =
      text  : "Ace"
      video : "Viewer"
      image : "Viewer"
      sound : "Viewer"

    @on 'AppManagerWantsToShowAnApp', @bound "setFrontApp"
    @on 'AppManagerWantsToShowAnApp', @bound "setMissingRoute"
    # @on 'AnInstanceIsShown', @bound "setMissingRoute"

    # set unload listener
    windowController = @getSingleton 'windowController'
    windowController.addUnloadListener 'window', =>
      safeToUnload = no for own app of @appControllers when app in ['Ace', 'WebTerm']
      return safeToUnload ? yes

  setMissingRoute:(appController, appView, appOptions)->
    router       = KD.getSingleton('router')
    {entryPoint} = KD.config

    route = appOptions.route.slug.replace /:\w+.?\//g, ''
    comparedRoute = router.getCurrentPath().split('?').first
    if route isnt comparedRoute
      missingRoute = appController.getOption('initialRoute') or route
      router.handleRoute missingRoute, { suppressListeners : yes, entryPoint }


  open: do ->

    createOrShow = (appOptions, appParams, callback = noop)->

      appManager  = KD.getSingleton "appManager"
      name        = appOptions?.name

      return appManager.handleAppNotFound()  unless name

      appInstance = appManager.get name
      cb          = -> appManager.show appOptions, callback
      if appInstance then do cb
      else appManager.create name, appParams, cb

    (name, options, callback)->

      return warn "ApplicationManager::open called without an app name!"  unless name

      [callback, options]  = [options, callback] if 'function' is typeof options
      options            or= {}
      appOptions           = KD.getAppOptions name
      appParams            = options.params or {}
      defaultCallback      = -> createOrShow appOptions, appParams, callback
      kodingAppsController = KD.getSingleton("kodingAppsController")

      # If app has a preCondition then first check condition in it
      # if it returns true then continue, otherwise call failure
      # method of preCondition if exists

      if appOptions?.preCondition? and not options.conditionPassed
        appOptions.preCondition.condition appParams, (state, newParams)=>
          if state
            options.conditionPassed = yes
            options.params = newParams  if newParams
            @open name, options, callback
          else
            params = newParams or appParams
            appOptions.preCondition.failure? params, callback
        return

      # if there is no registered appController
      # we assume it should be a 3rd party app
      # that's why it should be run via kodingAppsController

      if not appOptions? and not options.avoidRecursion?
        return @fetchManifests name, (err)=>
          options.avoidRecursion = yes
          unless err
          then @open name, options, callback
          else do defaultCallback

      appParams = options.params or {}

      if appOptions?.multiple
        if options.forceNew or appOptions.openWith is "forceNew"
          return @create name, appParams, (appInstance)=>
            @showInstance appInstance, callback

        switch appOptions.openWith
          when "lastActive" then do defaultCallback
          when "prompt"     then do defaultCallback
          # when "prompt"
          #   log "prompting"
          #   if @appControllers[name]?.instances.length > 1
          #     log "more than one, namely", @appControllers[name].instances.length
          #     @createPromptModal appOptions, (appInstanceIndex, openNew)=>
          #       if typeof appInstanceIndex is "number"
          #         appInstance = @appControllers[name].instances[appInstanceIndex]
          #         # user selected appInstance to open
          #         @show appInstance, callback
          #       else if openNew
          #         # user wants to open a fresh instance
          #         @create name, appParams, callback
          #       else
          #         warn "user cancelled app to open"
          #  else do defaultCallback

      else do defaultCallback

  openFileWithApplication: (appName, file) ->
    @open appName, =>
      @utils.defer => @getFrontApp().openFile file

  fetchManifests:(appName, callback)->

    KD.getSingleton("kodingAppsController").fetchApps (err, manifests)->
      manifestsFetched = yes

      return callback? yes  if err or not manifests

      for own name, manifest of manifests when name is appName

        err = no

        manifest.route        = slug : "/Develop/#{encodeURIComponent name}"
        manifest.behavior   or= "application"
        manifest.navItem      = title : "Develop"
        manifest.thirdParty  ?= yes

        KD.registerAppClass KodingAppController, manifest

      callback?()

  promptOpenFileWith:(file)->
    finderController = KD.getSingleton "finderController"
    {treeController} = finderController
    view = new KDView {}, file
    treeController.showOpenWithModal view

  openFile:(file)->

    extension  = file.getExtension()
    type       = FSItem.getFileType extension
    defaultApp = @defaultApps[extension]

    return @openFileWithApplication defaultApp, file  if defaultApp

    switch type
      when 'unknown'
        @promptOpenFileWith file
      when 'code','text'
        log "open with a text editor"
        @open @defaultApps.text, (appController)-> appController.openFile file
      when 'image'
        log "open with an image processing app"
      when 'video'
        log "open with a video app"
      when 'sound'
        log "open with a sound app"
      when 'archive'
        log "extract the thing."


  tell:(name, command, rest...)->

    return warn "ApplicationManager::tell called without an app name!"  unless name

    # log "::: Telling #{command} to #{name}"

    app = @get name
    cb  = (appInstance)-> appInstance?[command]? rest...

    if app then @utils.defer -> cb app
    else @create name, cb

  create:(name, params, callback)->

    [callback, params] = [params, callback]  unless callback

    AppClass              = KD.getAppClass name
    appOptions            = $.extend {}, true, KD.getAppOptions name
    appOptions.params     = params
    @register appInstance = new AppClass appOptions  if AppClass

    if appOptions.thirdParty
      if KD.getSingleton("kodingAppsController").hasForceUpdate appInstance
        @emit "AppCouldntBeCreated", appInstance
        @utils.defer => @quitByName appOptions.name, yes
        return no

    @utils.defer =>
      return @emit "AppCouldntBeCreated"  unless appInstance
      @emit "AppCreated", appInstance
      if appOptions.thirdParty
        KD.getSingleton("kodingAppsController").putAppResources appInstance, callback
      callback? appInstance

  show:(appOptions, callback)->

    appInstance = @get appOptions.name

    if appOptions.background
      return @utils.defer -> callback? appInstance

    appView     = appInstance.getView?()
    return unless appView

    @emit 'AppManagerWantsToShowAnApp', appInstance, appView, appOptions
    @setLastActiveIndex appInstance
    @utils.defer -> callback? appInstance

  showInstance:(appInstance, callback)->

    appView    = appInstance.getView?() or null
    appOptions = KD.getAppOptions appInstance.getOption "name"

    return if appOptions.background

    # if KD.isLoggedIn()
    @emit 'AppManagerWantsToShowAnApp', appInstance, appView, appOptions
    @emit 'AnInstanceIsShown', appInstance, appView, appOptions
    @setLastActiveIndex appInstance
    @utils.defer -> callback? appInstance
    # else
    #   KD.getSingleton('router').clear()

  quit:(appInstance, callback = noop)->

    destroyer = if view = appInstance.getView?() then view else appInstance
    destroyer.destroy()
    callback()

  quitAll:->

    for own name, apps of @appControllers
      @quit app  for app in apps.instances

  quitByName: (name, closeAllInstances = yes) ->
    appController = @appControllers[name]
    return  unless appController

    if closeAllInstances
      instances = appController.instances
      @quit instances[0] while instances.length > 0
    else
      @quit appController.instances[appController.lastActiveIndex]

  get:(name)->

    if apps = @appControllers[name]
      apps.instances[apps.lastActiveIndex] or apps.instances.first
    else
      null

  getByView: (view)->

    appInstance = null
    for own name, apps of @appControllers
      for appController in apps.instances
        if view.getId() is appController.getView?()?.getId()
          appInstance = appController
          break
      break if appInstance

    return appInstance

  getFrontApp:-> @frontApp

  setFrontApp:(appInstance)->

    @setLastActiveIndex appInstance
    @frontApp = appInstance

  getFrontAppManifest: ->
    {name}  = @getFrontApp().getOptions()
    return KD.getAppOptions name

  register:(appInstance)->

    name = appInstance.getOption "name"
    @appControllers[name] ?=
      instances       : []
      lastActiveIndex : null

    @appControllers[name].instances.push appInstance
    @setListeners appInstance

  unregister:(appInstance)->

    name  = appInstance.getOption "name"
    index = @appControllers[name].instances.indexOf appInstance

    if index >= 0
      @appControllers[name].instances.splice index, 1
      if @appControllers[name].instances.length is 0
        delete @appControllers[name]

  createPromptModal:(appOptions, callback)->
    # show modal and wait for response
    {name} = appOptions
    selectOptions = for instance, i in @appControllers[name].instances
      title : "#{instance.getOption('name')} (#{i+1})"
      value : i

    modal = new KDModalViewWithForms
      title                 : "Open with:"
      tabs                  :
        navigable           : no
        forms               :
          openWith          :
            callback        : (formOutput)->
              modal.destroy()
              {index, openNew} = formOutput
              callback index, openNew
            fields          :
              instance      : {
                label       : "Instance:"
                itemClass   : KDSelectBox
                name        : "index"
                type        : "select"
                defaultValue: selectOptions.first.value
                selectOptions
              }
              newOne        :
                label       : "Open new app:"
                itemClass   : KDOnOffSwitch
                name        : "openNew"
                defaultValue: no
            buttons         :
              Open          :
                cssClass    : "modal-clean-green"
                type        : "submit"
              Cancel        :
                cssClass    : "modal-cancel"
                callback    : ->
                  modal.cancel()
                  callback null

  setListeners:(appInstance)->

    destroyer = if view = appInstance.getView?() then view else appInstance
    destroyer.once "KDObjectWillBeDestroyed", =>
      @unregister appInstance
      appInstance.emit "AppDidQuit"
      KD.getSingleton('appManager').emit  "AppDidQuit", appInstance

  setLastActiveIndex:(appInstance)->

    return unless appInstance

    if optionSet = @appControllers[appInstance.getOption "name"]
      index = optionSet.instances.indexOf appInstance
      if index is -1 then optionSet.lastActiveIndex = null
      else optionSet.lastActiveIndex = index


  # setGroup:-> console.log 'setGroup', arguments

  # temp
  notification = null

  notify:(msg)->

    notification.destroy() if notification

    notification = new KDNotificationView
      title     : msg or "Currently disabled!"
      type      : "mini"
      duration  : 2500

  handleAppNotFound: ->
    KD.getSingleton("router").handleRoute "/Develop"
    new KDNotificationView
      title    : "You don't have this app installed!"
      type     : "mini"
      cssClass : "error"
      duration : 5000

  # deprecate these

  # fetchStorage: (appId, version, callback) ->
  #   # warn "System still trying to access application storage for #{appId}"
  #   KD.whoami().fetchStorage {appId, version}, (error, storage) =>
  #     unless storage
  #       storage = {appId,version,bucket:{}} # creating a fake storage
  #     callback error, storage