class MainTabView extends KDTabView

  constructor:(options,data)->
    options.resizeTabHandles    = yes
    options.lastTabHandleMargin = 40
    options.sortable            = yes
    @visibleHandles             = []
    @totalSize                  = 0
    super options,data
    @router                     = KD.getSingleton 'router'
    @appManager                 = KD.getSingleton("appManager")

    @appManager.on 'AppManagerWantsToShowAnApp', (controller, view, options)=>
      if view.parent
      then @showPane view.parent
      else @createTabPane options, view

    # KD.getSingleton("mainView").on "mainViewTransitionEnd", (e) =>
    #   if e.target is KD.getSingleton("contentPanel").domElement[0]
    #     @tabHandleContainer.setWidth @getWidth()
    #     @resizeTabHandles()

    # @on "PaneAdded", =>
    #   @tabHandleContainer.setWidth @getWidth()

    # mainViewController = KD.getSingleton "mainViewController"
    # mainViewController.on "UILayoutNeedsToChange", @bound "changeLayout"

  # changeLayout:(options)->

  #   {hideTabs} = options

  #   if hideTabs
  #     @hideHandleContainer()
  #   else
  #     if KD.getSingleton('contentPanel').navOpenedOnce
  #       @showHandleContainer()


  handleClicked:(index, event)->
    pane        = @getPaneByIndex index
    appView     = pane.getMainView()
    appInstance = @appManager.getByView appView
    options     = appInstance.getOptions()

    if $(event.target).hasClass "close-tab"
      {quitOptions} = pane.mainView
      if quitOptions
        @warnClosingMultipleTabs appInstance, quitOptions
      else
        @appManager.quit appInstance
      return no
    else
      @appManager.showInstance appInstance

  # showHandleContainer:->
    # @tabHandleContainer.setClass 'in'
    # @handlesHidden = no

  # hideHandleContainer:->
    # @tabHandleContainer.unsetClass 'in'
    # @handlesHidden = yes

  showPane:(pane)->

    # this is to hide stale static tabs
    @$("> .kdtabpaneview").removeClass "active"
    @$("> .kdtabpaneview").addClass "kdhiddentab"

    super pane

    @emit "MainTabPaneShown", pane

    return pane

  removePane: (pane) ->
    # we don't want to use ::showPane
    # to show the previousPane when a pane
    # is removed, that's why we override it to use
    # kodingrouter

    index        = @getPaneIndex pane
    visibles     = @getVisibleTabs?()
    visibleIndex = visibles.indexOf pane
    leftPane     = visibles[visibleIndex - 1]
    rightPane    = visibles[visibleIndex + 1]

    pane.emit "KDTabPaneDestroy"

    isActivePane = @getActivePane() is pane
    @panes.splice index, 1
    pane.destroy()
    handle = @getHandleByIndex index
    @handles.splice index, 1
    handle.destroy()
    @emit "PaneRemoved"

    if rightPane
      @appManager.showInstance @appManager.getByView rightPane.mainView
    else if leftPane
      @appManager.showInstance @appManager.getByView leftPane.mainView
    else
      @router.handleRoute "/Activity"

  createTabPane:(options = {}, mainView)->

    o = {}
    o.cssClass = @utils.curry "content-area-pane", options.cssClass
    o.class  or= KDView

    # adding a domId is a temporary hack
    # for reviving the main tabs
    # a better solution tbdl - SY

    domId           = "maintabpane-#{@utils.slugify options.name}"
    o.domId         = domId  if document.getElementById domId
    o.name          = options.name
    o.behavior      = options.behavior
    o.hiddenHandle  = options.hiddenHandle
    o.view          = mainView
    paneInstance    = new MainTabPane o

    paneInstance.once "viewAppended", =>
      @applicationPaneReady paneInstance, mainView
      appController = @appManager.getByView mainView
      {appInfo}     = appController.getOptions()
      paneInstance.setTitle appInfo.title  if appInfo?.title

    @addPane paneInstance

    return paneInstance

  applicationPaneReady: (pane, mainView) ->
    if pane.getOption("behavior") is "application"
      mainView.setClass 'application-page'

    mainView.on "KDObjectWillBeDestroyed", @removePane.bind this, pane

  rearrangeVisibleHandlesArray:->
    @visibleHandles = []
    for handle in @handles
      unless handle.getOptions().hidden
        @visibleHandles.push handle

  warnClosingMultipleTabs: (appInstance, quitOptions) ->
    title   = quitOptions.title   or "Do you want to close multiple tabs?"
    content = quitOptions.message or "Please make sure that you saved all your work."

    modal   = new KDModalView
      cssClass      : "modal-with-text"
      title         : "#{title}"
      content       : "<p>#{content}</p>"
      overlay       : yes
      buttons       :
        "Close"     :
          cssClass  : "modal-clean-gray"
          title     : "Close"
          callback  : =>
            @appManager.quit appInstance
            modal.destroy()
        "Cancel"    :
          cssClass  : "modal-cancel"
          title     : "Cancel"
          callback  : =>
            modal.destroy()
