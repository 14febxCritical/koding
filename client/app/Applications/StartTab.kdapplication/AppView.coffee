class StartTabMainView extends JView

  constructor:(options, data)->

    options.cssClass or= 'start-tab'

    super

    @listenWindowResize()

    @appIcons      = {}
    mainView       = @getSingleton('mainView')
    appsController = @getSingleton("kodingAppsController")
    appsController.on "AppsRefreshed", (apps)=>
      @decorateApps apps

    # mainView.sidebar.finderResizeHandle.on "DragInAction", =>
    #   log "DragInAction", mainView.contentPanel.getWidth()

    # mainView.sidebar.finderResizeHandle.on "DragFinished", =>
    #   @utils.wait 301, =>
    #     log "DragFinished", mainView.contentPanel.getWidth()

    @loader = new KDLoaderView
      size    :
        width : 16

    @refreshButton = new KDButtonView
      cssClass    : "editor-button"
      title       : "Refresh Apps"
      loader      :
        diameter  : 16
      callback    : =>
        @removeAppIcons()
        @showLoader()
        appsController.refreshApps (err, apps)=>
          @hideLoader()
          @refreshButton.hideLoader()

    @addAnAppButton = new KDButtonView
      cssClass    : "editor-button"
      # icon        : yes
      # iconClass   : "make-an-app"
      title       : "Make a new App"
      callback    : =>
        appsController.makeNewApp =>
          new KDNotificationView
            type  : "mini"
            title : "App is created! Check your Applications folder!"

          @removeAppIcons()
          @showLoader()
          appsController.refreshApps =>
            @hideLoader()

    # appManager.fetchStorage "KodingApps", "1.0", (err, storage)=>
    #   storage.update $set : { "bucket.apps" : {} }, =>
    #     @hideLoader()
    #     log arguments, "kodingAppsController storage cleared"

    @appItemContainer = new StartTabAppItemContainer
      cssClass : 'app-item-container'
      delegate : @

    @noAppsWarning = new KDView
      cssClass : 'no-apps hidden'
      partial  : 'you have no apps!'

    @recentFilesWrapper = new KDView
      cssClass : 'file-container'

  showLoader:->

    @loader.show()
    @$('h1.loaded, h2.loaded').addClass "hidden"
    @$('h2.loader').removeClass "hidden"

  hideLoader:->

    @loader.hide()
    @$('h2.loader').addClass "hidden"
    @$('h1.loaded, h2.loaded').removeClass "hidden"

  viewAppended:->

    super
    # @addApps()
    @addRealApps()
    @addSplitOptions()
    @addRecentFiles()

  _windowDidResize:->



  addApps:->

    for app in apps
      @appItemContainer.addSubView new StartTabOldAppThumbView
        tab : @
      , app

  pistachio:->
    """
    <div class='app-list-wrapper'>
      <div class='app-button-holder hidden1'>
        {{> @addAnAppButton}}
        {{> @refreshButton}}
      </div>
      <header>
        <h1 class="start-tab-header loaded hidden">To start from a new file, select an editor</h1>
        <h2 class="loaded hidden">or open an existing file from your file tree</h2>
        <h2 class="loader">{{> @loader}} Loading applications...</h1>
      </header>
      {{> @appItemContainer}}
      {{> @noAppsWarning}}
    </div>
    <div class='start-tab-split-options expanded'>
      <h3>Start with a workspace</h3>
    </div>
    <div class='start-tab-recent-container'>
      <h3>Recent files:</h3>
      {{> @recentFilesWrapper}}
    </div>
    """

  addRealApps:->

    @removeAppIcons()
    @showLoader()
    @getSingleton("kodingAppsController").fetchApps (err, apps)=>
      @hideLoader()
      @decorateApps apps

  decorateApps:(apps)->

    @removeAppIcons()
    if apps
      @noAppsWarning.hide()
      @putAppIcons apps
    else
      @noAppsWarning.show()

  removeAppIcons:->

    @appItemContainer.destroySubViews()
    @appIcons = {}

  putAppIcons:(apps)->

    @refreshButton.show()
    @hideLoader()
    for app, manifest of apps
      do (app, manifest)=>
        @appItemContainer.addSubView @appIcons[manifest.name] = new StartTabAppThumbView
          delegate : @
        , manifest

  addSplitOptions:->
    for splitOption in getSplitOptions()
      option = new KDCustomHTMLView
        tagName   : 'a'
        cssClass  : 'start-tab-split-option'
        partial   : splitOption.partial
        click     : -> appManager.notify()
      @addSubView option, '.start-tab-split-options'

  addRecentFiles:->

    @recentFileViews = {}

    appManager.fetchStorage 'Finder', '1.0', (err, storage)=>

      storage.on "update", => @updateRecentFileViews()

      if err
        error "couldn't fetch the app storage.", err
      else
        recentFilePaths = storage.getAt('bucket.recentFiles')
        @updateRecentFileViews()
        @getSingleton('mainController').on "NoSuchFile", (file)=>
          recentFilePaths.splice recentFilePaths.indexOf(file.path), 1
          # log "updating storage", recentFilePaths.length
          storage.update {
            $set: 'bucket.recentFiles': recentFilePaths
          }, => log "storage updated"


  updateRecentFileViews:()->

    appManager.fetchStorage 'Finder', '1.0', (err, storage)=>

      recentFilePaths = storage.getAt('bucket.recentFiles')
      # log "updating views", recentFilePaths.length

      for path, view of @recentFileViews
        @recentFileViews[path].destroy()
        delete @recentFileViews[path]

      if recentFilePaths?.length
        recentFilePaths.forEach (filePath)=>
          @recentFileViews[filePath] = new StartTabRecentFileItemView {}, filePath
          @recentFilesWrapper.addSubView @recentFileViews[filePath]
      else
        @recentFilesWrapper.hide()

  createSplitView:(type)->

  getSplitOptions = ->
    [
      {
        partial               : '<span class="fl w50"></span><span class="fr w50"></span>'
        splitType             : 'vertical'
        splittingFromStartTab : yes
        splits                : [1,1]
      },
      {
        partial               : '<span class="fl h50 w50"></span><span class="fr h50 w50"></span><span class="h50 full-b"></span>'
        splitType             : 'horizontal'
        secondSplitType       : 'vertical'
        splittingFromStartTab : yes
        splits                : [2,1]
      },
      {
        partial               : '<span class="h50 full-t"></span><span class="fl w50 h50"></span><span class="fr w50 h50"></span>'
        splitType             : 'horizontal'
        secondSplitType       : 'vertical'
        splittingFromStartTab : yes
        splits                : [1,2]
      },
      {
        partial               : '<span class="fl w50 h50"></span><span class="fr w50 full-r"></span><span class="fl w50 h50"></span>'
        splitType             : 'vertical'
        secondSplitType       : 'horizontal'
        splittingFromStartTab : yes
        splits                : [2,1]
      },
      {
        partial               : '<span class="fl w50 full-l"></span><span class="fr w50 h50"></span><span class="fr w50 h50"></span>'
        splitType             : 'vertical'
        secondSplitType       : 'horizontal'
        splittingFromStartTab : yes
        splits                : [1,2]
      },
      {
        partial               : '<span class="fl w50 h50"></span><span class="fr w50 h50"></span><span class="fl w50 h50"></span><span class="fr w50 h50"></span>'
        splitType             : 'vertical'
        secondSplitType       : 'horizontal'
        splittingFromStartTab : yes
        splits                : [2,2]
      },
    ]
