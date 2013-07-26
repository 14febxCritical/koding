class MainView extends KDView

  viewAppended:->

    @bindTransitionEnd()
    # @addServerStack()
    @addHeader()
    @createMainPanels()
    @createMainTabView()
    @setStickyNotification()
    @createSideBar()
    @createChatPanel()
    @listenWindowResize()

    @utils.defer => @_windowDidResize()

  putAbout:->

    KDView.appendToDOMBody overlay = new KDView
      cssClass : 'about-overlay'
    overlay.bindTransitionEnd()

    logo = new KDCustomHTMLView
      cssClass : 'main-loading'
      partial  : '<ul><li/><li/><li/><li/><li/><li/></ul>'

    overlay.once 'transitionend', ->
      overlay.addSubView logo
      KD.utils.defer -> logo.$('>ul').addClass 'in'
      KD.utils.wait 4000, -> about.setClass 'in'

    @utils.defer -> overlay.setClass 'in'

    {winHeight} = KD.getSingleton('windowController')

    offset = if winHeight > 400 then (winHeight - 400) / 2 else 0

    KDView.appendToDOMBody about = new AboutView
      domId   : 'about-text'
      click   : =>
        about.once 'transitionend', ->
          about.destroy()
          overlay.once 'transitionend', ->
            overlay.destroy()
          overlay.unsetClass 'in'
        about.unsetClass 'in'

    about.setY offset
    about.bindTransitionEnd()

  addBook:-> 
    @addSubView new BookView 
      delegate : this
    

  _windowDidResize:->

    {winHeight} = KD.getSingleton "windowController"
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

    @appSettingsMenuButton = new AppSettingsMenuButton
    @appSettingsMenuButton.hide()

    @mainTabView = new MainTabView
      domId              : "main-tab-view"
      listenToFinder     : yes
      delegate           : @
      slidingPanes       : no
      tabHandleContainer : @mainTabHandleHolder
    ,null

    @mainTabView.on "PaneDidShow", =>
      appManager  = KD.getSingleton "appManager"
      appManifest = appManager.getFrontAppManifest()
      menu = appManifest?.menu or KD.getAppOptions(appManager.getFrontApp().getOptions().name)?.menu
      if Array.isArray menu
        menu = items: menu
      if menu?.items?.length
        @appSettingsMenuButton.setData menu
        @appSettingsMenuButton.show()
      else
        @appSettingsMenuButton.hide()

    @mainTabView.on "AllPanesClosed", ->
      KD.getSingleton('router').handleRoute "/Activity"

    @contentPanel.addSubView @mainTabView
    @contentPanel.addSubView @mainTabHandleHolder
    @contentPanel.addSubView @appSettingsMenuButton

  createSideBar:->

    @sidebar             = new Sidebar domId : "sidebar", delegate : @
    mc                   = KD.getSingleton 'mainController'
    mc.sidebarController = new SidebarController view : @sidebar
    @sidebarPanel.addSubView @sidebar

  createChatPanel:->
    @addSubView @chatPanel   = new MainChatPanel
    @addSubView @chatHandler = new MainChatHandler

  setStickyNotification:->
    # sticky = KD.getSingleton('windowController')?.stickyNotification
    @utils.defer => getStatus()

    KD.remote.api.JSystemStatus.on 'restartScheduled', (systemStatus)=>
      sticky = KD.getSingleton('windowController')?.stickyNotification

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

  enableFullscreen: ->
    @contentPanel.$().addClass "fullscreen no-anim"
    $(window).resize()

  disableFullscreen: ->
    @contentPanel.$().removeClass "fullscreen no-anim"
    $(window).resize()

  isFullscreen: ->
    @contentPanel.$().is ".fullscreen"

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

    # mainController = KD.getSingleton('mainController')
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
