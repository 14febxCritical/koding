class MainTabView extends KDTabView
  constructor:(options,data)->
    @visibleHandles = []
    @totalSize      = 0
    @paneViewIndex  = {}
    super options,data

    @listenTo
      KDEventTypes : 'ApplicationWantsToBeShown'
      callback     :(app, {options, data})->
        @showPaneByView options, data

    @listenTo
      KDEventTypes : 'ApplicationWantsToClose'
      callback     :(app, {options, data})->
        @removePaneByView data

    @listenTo
      KDEventTypes : 'FileChanged'
      callback     : @fileChanged

  showHandleContainer:()->
    @tabHandleContainer.$().css top : -25
    @handlesHidden = no

  hideHandleContainer:()->
    @tabHandleContainer.$().css top : 0
    @handlesHidden = yes

  showPane:(pane)->
    super pane

    paneMainView = pane.getMainView()
    if paneMainView.data?.constructor.name is 'FSFile'
      @getSingleton('mainController').emit "SelectedFileChanged", paneMainView.data

    paneMainView.handleEvent type : "click"
    @handleEvent {type : "MainTabPaneShown", pane}

    return pane

  fileChanged: (appController, data) ->
    # file        = data.file
    # oldContent  = file.contents or ''
    # newContent  = data.newContent
    #
    # changed = no
    # if oldContent isnt newContent
    #   changed = yes
    #
    # view        = data.appView
    # pane        = @getPaneByView view
    #
    # newTitle    = (if changed then '*' else '') + file.name
    # pane.setTitle newTitle


  _removePane: (pane) ->
    pane.handleEvent type : "KDTabPaneDestroy"
    index = @getPaneIndex pane
    isActivePane = @getActivePane() is pane
    @panes.splice(index,1)
    pane.destroy()
    @unindexPaneByView pane, pane.getData()
    handle = @getHandleByIndex index
    @handles.splice(index,1)
    handle.destroy()
    if isActivePane
      appPanes = []
      for pane in @panes
        appPanes.push pane if pane.options.type is "application"

      if appPanes.length > 0
        @showPane appPanes[0]
      else
        newIndex = if @getPaneByIndex(index-1)? then index-1 else 0
        @showPane @getPaneByIndex(newIndex) if @getPaneByIndex(newIndex)?

    @emit "PaneRemoved"

  removePane:(pane)->
    pane.getData().handleEvent type: 'ViewClosed'
    # delete appManager.terminalIsOpen if pane.getData().$().hasClass('terminal-tab')

  showPaneByView:(options,view)->
    viewId = view
    unless (@getPaneByView view)?
      @createTabPane options,view
    else
      @showPane @getPaneByView view

  removePaneByView:(view)->
    return unless (pane = @getPaneByView view)
    @_removePane pane

  getPaneByView:(view)->
    if view then @paneViewIndex[view.id] else null

  indexPaneByView:(pane,view)->
    @paneViewIndex[view.id] = pane

  unindexPaneByView:(pane,view)->
    delete @paneViewIndex[view.id]

  createTabPane:(options,mainView)->
    @removePaneByView mainView if mainView?

    options = $.extend
      cssClass     : "content-area-pane #{__utils.slugify(options?.name?.toLowerCase()) or ""} content-area-new-tab-pane"
      hiddenHandle : yes
      type         : "content"
      class        : KDView
    ,options
    paneInstance = new MainTabPane options,mainView
    # debugger
    # log 'options', options
    paneInstance.on "viewAppended", =>
      # if options.controller  #dont need that anymore as tabHandle could be controlled by application
      #   options.controller.applicationPaneReady? mainView, paneInstance
      @applicationPaneReady paneInstance, mainView

    @addPane paneInstance
    @indexPaneByView paneInstance,mainView

    return paneInstance

  applicationPaneReady: (pane, mainView) ->
    # mainView.setDelegate pane
    mainView.setClass 'application-page' if pane.options.type is "application"
    pane.setMainView mainView

  tabPaneReady:(pane,event)->
    pageClass = KDView
    type = "content"
    if /^ace/.test pane.name
      pageClass = KD.getPageClass("Editor")
      type = "application"
    else if /^shell/.test pane.name
      pageClass = KD.getPageClass("Shell")
      type = "application"
    else
      pageClass = KD.getPageClass(pane.name) if KD.getPageClass(pane.name)

    pane.addSubView page = new pageClass
      delegate : pane
      cssClass : "#{type}-page"


  rearrangeVisibleHandlesArray:->
    @visibleHandles = []
    for handle in @handles
      unless handle.getOptions().hidden
        @visibleHandles.push handle


  resizeTabHandles:(event)->

    return if event.type is "PaneAdded" and event.pane.hiddenHandle
    return if @handlesHidden

    containerSize   = @tabHandleContainer.getWidth()
    {plusHandle}    = @tabHandleContainer

    if event.type in ['PaneAdded','PaneRemoved']
      @totalSize    = 0
      @rearrangeVisibleHandlesArray()
      for handle in @visibleHandles
        @totalSize += handle.$().outerWidth(no)

    plusHandleWidth = plusHandle.$().outerWidth(no)
    containerSize -= plusHandleWidth

    handleSize = if containerSize < @totalSize
      containerSize / @visibleHandles.length
    else
      if containerSize / @visibleHandles.length > 130
        130
      else
        containerSize / @visibleHandles.length

    for handle in @visibleHandles
      handle.$().css width : handleSize
      subtractor = if handle.$('span').length is 1 then 25 else 25 + (handle.$('span:not(".close-tab")').length * 25)
      handle.$('> b').css width : (handleSize - subtractor)





