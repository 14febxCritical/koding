class MainView extends KDView

  viewAppended:->

    @bindTransitionEnd()
    # @addServerStack()
    @addHeader()
    @createMainPanels()
    @createMainTabView()
    @setStickyNotification()
    @createSideBar()
    @listenWindowResize()

    @utils.defer => @_windowDidResize()

  putAbout:->

    @putOverlay
      color   : "rgba(0,0,0,0.9)"
      animated: yes
    @$('section').addClass "scale"

    @utils.wait 500, =>
      @addSubView about = new AboutView
        domId   : "about-text"
        click   : @bound "removeOverlay"

      @once "OverlayWillBeRemoved", about.bound "destroy"
      @once "OverlayWillBeRemoved", => @$('section').removeClass "scale"

  addBook:-> @addSubView new BookView

  _windowDidResize:->

    {winHeight} = @getSingleton "windowController"
    @panelWrapper.setHeight winHeight - 51

  createMainPanels:->

    @addSubView @panelWrapper = new KDView
      tagName  : "section"
      domId    : "main-panel-wrapper"

    @panelWrapper.addSubView @sidebarPanel = new KDView
      domId    : "sidebar-panel"
    @registerSingleton "sidebarPanel", @sidebarPanel, yes

    @panelWrapper.addSubView @contentPanel = new ContentPanel
      domId    : "content-panel"
      cssClass : "transition"

    @contentPanel.on "ViewResized", (rest...)=> @emit "ContentPanelResized", rest...

  addServerStack:->
    @addSubView @serverStack = new KDView
      domId : "server-rack"
      click : ->
        $('body').removeClass 'server-stack'
        $('.kdoverlay').remove()

  addHeader:->

    @addSubView @header = new KDView
      tagName : "header"
      domId   : "main-header"

    {entryPoint} = KD.config
    @header.addSubView @logo = new KDCustomHTMLView
      tagName   : "a"
      domId     : "koding-logo"
      cssClass  : if entryPoint?.type? is 'group' then 'group' else ''
      partial   : "<span></span>"
      click     : (event)=>
        # return if @userEnteredFromGroup()
        event.stopPropagation()
        event.preventDefault()

        KD.getSingleton('router').handleRoute "/Activity", {entryPoint}

    if entryPoint?.slug? and entryPoint.type is "group"
      KD.remote.cacheable entryPoint.slug, (err, models)=>
        if err then callback err
        else if models?
          [group] = models
          @logo.updatePartial "<span></span>#{group.title}"


  createMainTabView:->

    @mainTabHandleHolder = new MainTabHandleHolder
      domId    : "main-tab-handle-holder"
      cssClass : "kdtabhandlecontainer"
      delegate : @

    @mainSettingsMenuButton = @getMainSettingsMenuButton()

    @mainTabView = new MainTabView
      domId              : "main-tab-view"
      listenToFinder     : yes
      delegate           : @
      slidingPanes       : no
      tabHandleContainer : @mainTabHandleHolder
    ,null

    @mainTabView.on "PaneDidShow", => @utils.wait 10, =>
      appManifest = getFrontAppManifest()
      @mainSettingsMenuButton[if appManifest?.menu then "show" else "hide"]()

    @mainTabView.on "AllPanesClosed", ->
      @getSingleton('router').handleRoute "/Activity"

    @contentPanel.addSubView @mainTabView
    @contentPanel.addSubView @mainTabHandleHolder
    @contentPanel.addSubView @mainSettingsMenuButton

  createSideBar:->

    @sidebar             = new Sidebar domId : "sidebar", delegate : @
    mc                   = @getSingleton 'mainController'
    mc.sidebarController = new SidebarController view : @sidebar
    @sidebarPanel.addSubView @sidebar

  getMainSettingsMenuButton: ->
    new KDButtonView
      domId    : "main-settings-menu"
      cssClass : "kdsettingsmenucontainer transparent"
      iconOnly : yes
      iconClass: "dot"
      callback : ->
        appManifest = getFrontAppManifest()
        if appManifest?.menu
          appManifest.menu.forEach (item, index)->
            item.callback = (contextmenu)->
              mainView = KD.getSingleton "mainView"
              view = mainView.mainTabView.activePane?.mainView
              item.eventName or= item.title
              view?.emit "menu.#{item.eventName}", item.eventName, item, contextmenu

          offset = @$().offset()
          contextMenu = new JContextMenu
              event       : event
              delegate    : @
              x           : offset.left - 150
              y           : offset.top + 20
              arrow       :
                placement : "top"
                margin    : -5
            , appManifest.menu

  setStickyNotification:->
    # sticky = @getSingleton('windowController')?.stickyNotification
    @utils.defer => getStatus()

    KD.remote.api.JSystemStatus.on 'restartScheduled', (systemStatus)=>
      sticky = @getSingleton('windowController')?.stickyNotification

      if systemStatus.status isnt 'active'
        getSticky()?.emit 'restartCanceled'
      else
        systemStatus.on 'restartCanceled', =>
          getSticky()?.emit 'restartCanceled'
        new GlobalNotification
          targetDate : systemStatus.scheduledAt
          title      : systemStatus.title
          content    : systemStatus.content
          type       : systemStatus.type


  # take this to appManager SY
  getFrontAppManifest = ->
    appManager    = KD.getSingleton "appManager"
    appController = KD.getSingleton "kodingAppsController"
    frontApp      = appManager.getFrontApp()
    frontAppName  = name for name, instances of appManager.appControllers when frontApp in instances
    appController.constructor.manifests?[frontAppName]

  getSticky = =>
    KD.getSingleton('windowController')?.stickyNotification

  getStatus = =>
    KD.remote.api.JSystemStatus.getCurrentSystemStatus (err,systemStatus)=>
      if err
        if err.message is 'none_scheduled'
          getSticky()?.emit 'restartCanceled'
        else
          log 'current system status:',err
      else
        systemStatus.on 'restartCanceled', =>
          getSticky()?.emit 'restartCanceled'
        new GlobalNotification
          targetDate  : systemStatus.scheduledAt
          title       : systemStatus.title
          content     : systemStatus.content
          type        : systemStatus.type


# inactive code

    # mainController = @getSingleton('mainController')
    # mainController.popupController = new VideoPopupController

    # mainController.monitorController = new MonitorController

    # @videoButton = new KDButtonView
    #   cssClass : "video-popup-button"
    #   icon : yes
    #   title : "Video"
    #   callback :=>
    #     unless @popupList.$().hasClass "hidden"
    #       @videoButton.unsetClass "active"
    #       @popupList.hide()
    #     else
    #       @videoButton.setClass "active"
    #       @popupList.show()

    # @videoButton.hide()

    # @popupList = new VideoPopupList
    #   cssClass      : "hidden"
    #   type          : "videos"
    #   itemClass     : VideoPopupListItem
    #   delegate      : @
    # , {}
    # @contentPanel.addSubView @videoButton
    # @contentPanel.addSubView @popupList
