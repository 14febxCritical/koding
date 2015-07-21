$                     = require 'jquery'
kd                    = require 'kd'
nick                  = require 'app/util/nick'
FSFile                = require 'app/util/fs/fsfile'
KDView                = kd.View
FSHelper              = require 'app/util/fs/fshelper'
IDEHelpers            = require '../../idehelpers'
IDEEditorPane         = require '../../workspace/panes/ideeditorpane'
KDContextMenu         = kd.ContextMenu
KDTabPaneView         = kd.TabPaneView
IDEPreviewPane        = require '../../workspace/panes/idepreviewpane'
IDEDrawingPane        = require '../../workspace/panes/idedrawingpane'
IDETerminalPane       = require '../../workspace/panes/ideterminalpane'
KDCustomHTMLView      = kd.CustomHTMLView
KDSplitViewPanel      = kd.SplitViewPanel
ProximityNotifier     = require './splithandleproximitynotifier'
IDEWorkspaceTabView   = require '../../workspace/ideworkspacetabview'
IDEApplicationTabView = require './ideapplicationtabview.coffee'
showErrorNotification = require 'app/util/showErrorNotification'

HANDLE_PROXIMITY_DISTANCE   = 100
DEFAULT_SESSION_NAME_LENGTH = 24

module.exports = class IDEView extends IDEWorkspaceTabView

  constructor: (options = {}, data) ->

    options.tabViewClass     = IDEApplicationTabView
    options.createNewEditor ?= yes
    options.bind             = 'dragover drop'
    options.addSplitHandlers ?= yes

    super options, data

    @openFiles = []
    @bindListeners()


  bindListeners: ->

    @on 'PlusHandleClicked', @bound 'createPlusContextMenu'
    @on 'CloseHandleClicked', @bound 'closeSplitView'
    @on 'FullscreenHandleClicked', @bound 'toggleFullscreen'
    @on 'VerticalSplitHandleClicked', =>
      {frontApp} = kd.singletons.appManager
      frontApp.setActiveTabView @tabView
      frontApp.splitVertically()
      @ensureSplitHandlers()
    @on 'HorizontalSplitHandleClicked', =>
      {frontApp} = kd.singletons.appManager
      frontApp.setActiveTabView @tabView
      frontApp.splitHorizontally()
      @ensureSplitHandlers()

    @tabView.on 'MachineTerminalRequested', @bound 'openMachineTerminal'
    @tabView.on 'MachineWebPageRequested',  @bound 'openMachineWebPage'
    @tabView.on 'TerminalPaneRequested',    @bound 'createTerminal'
    # obsolete: 'preview file' feature was removed (bug #82710798)
    @tabView.on 'PreviewPaneRequested',     (url) -> global.open "http://#{url}"
    @tabView.on 'DrawingPaneRequested',     @bound 'createDrawingBoard'
    @tabView.on 'ViewNeedsToBeShown',       @bound 'showView'
    @tabView.on 'TabNeedsToBeClosed',       @bound 'closeTabByFile'
    @tabView.on 'GoToLineRequested',        @bound 'goToLine'

    @tabView.on 'FileNeedsToBeOpened', (file, contents, callback, emitChange) =>
      @closeUntitledFileIfNotChanged()
      @openFile file, contents, callback, emitChange

    @tabView.on 'PaneDidShow', =>
      @updateStatusBar()
      @focusTab()

    @tabView.on 'PaneAdded', (pane) =>

      { addSplitHandlers } = @getOptions()

      @ensureSplitHandlers()  if addSplitHandlers

      { tabHandle, view } = pane
      { options }  = view
      { paneType } = options

      switch paneType
        when 'editor' then tabHandle.enableContextMenu()
        when 'terminal'
          tabHandle.enableContextMenu()

          webtermCallback = @lazyBound 'handleWebtermCreated', pane
          view.once 'WebtermCreated', webtermCallback

          handleCallback = @bound 'handleTerminalRenamingRequested'
          tabHandle.on 'RenamingRequested', handleCallback

          tabHandle.makeEditable()


    @tabView.on 'PaneRemoved', ({ pane, handle }) =>

      handle.off 'RenamingRequested', @bound 'handleTerminalRenamingRequested'


    # This is a custom event for IDEApplicationTabView
    # to distinguish between user actions and programmed actions
    @tabView.on 'PaneRemovedByUserAction', (pane)=>
      {view} = pane
      if view instanceof IDETerminalPane
        sessionId = view.session or view.webtermView.sessionId
        @terminateSession @mountedMachine, sessionId


  createSplitHandle = (type) ->

    handle = new kd.CustomHTMLView
      cssClass : "split-handle #{type}-split-handle"
      partial  : '<span class="icon"></span>'

    return handle


  ensureSplitHandlers: ->

    @verticalSplitHandle?.destroy()

    @tabView.addSubView @verticalSplitHandle = createSplitHandle 'vertical'
    @verticalSplitHandle.on 'click', @lazyBound 'emit', 'VerticalSplitHandleClicked'

    notifier = setupSplitHandleNotifier @verticalSplitHandle
    @on 'KDObjectWillBeDestroyed', notifier.bound 'destroy'

    @horizontalSplitHandle?.destroy()

    @tabView.addSubView @horizontalSplitHandle = createSplitHandle 'horizontal'
    @horizontalSplitHandle.on 'click', @lazyBound 'emit', 'HorizontalSplitHandleClicked'

    notifier = setupSplitHandleNotifier @horizontalSplitHandle
    @on 'KDObjectWillBeDestroyed', notifier.bound 'destroy'


  createPane_: (view, paneOptions, paneData) ->

    unless view or paneOptions
      return new Error 'Missing argument for createPane_ helper'

    unless view instanceof KDView
      return new Error 'View must be an instance of KDView'

    if view instanceof IDEEditorPane
      paneOptions.name = @trimUntitledFileName paneOptions.name

    pane = new KDTabPaneView paneOptions, paneData
    pane.addSubView view
    pane.view = view
    @tabView.addPane pane

    pane.once 'KDObjectWillBeDestroyed', => @handlePaneRemoved pane

    return pane


  trimUntitledFileName: (name) ->

    untitledNameRegex = /Untitled[0-9\-]*.txt/
    matchedPattern    = untitledNameRegex.exec name

    return  if matchedPattern then matchedPattern.first else name


  createEditor: (file, content, callback = kd.noop, emitChange = yes) ->

    unless file # create dummy file and pass machine to that file
      path    = @getDummyFilePath()
      machine = kd.singletons.appManager.getFrontApp().mountedMachine
      file    = FSHelper.createFileInstance { path, machine }

    # we need to show a notification that file is read-only or not accessible
    # only if it is opened by user action
    # we use emitChange to detect this case for now
    notifyIfNoPermissions = emitChange

    if file.isDummyFile() or not notifyIfNoPermissions
      return @createEditorAfterFileCheck file, content, callback, emitChange, no

    file.fetchPermissions (err, result) =>

      return showErrorNotification err  if err

      { readable, writable } = result
      if not readable
        IDEHelpers.showFileAccessDeniedError()
        return callback()

      @createEditorAfterFileCheck file, content, callback, emitChange, not writable


  createEditorAfterFileCheck: (file, content, callback, emitChange, isReadOnly) ->

    content     = content or ''
    editorPane  = new IDEEditorPane { file, content, delegate: this }

    paneOptions =
      name      : file.name
      editor    : editorPane
      aceView   : editorPane.aceView

    editorPane.once 'EditorIsReady', =>
      ace        = editorPane.getAce()
      appManager = kd.getSingleton 'appManager'

      if file.isDummyFile()
        ace.on 'FileContentChanged', => @emit 'UpdateWorkspaceSnapshot'

      ace.on 'ace.change.cursor', (cursor) ->
        appManager.tell 'IDE', 'updateStatusBar', 'editor', { file, cursor }

      ace.on 'FindAndReplaceViewRequested', (withReplaceMode) ->
        appManager.tell 'IDE', 'showFindReplaceView', withReplaceMode

      ace.editor.scrollToRow 0
      editorPane.goToLine 1

      if isReadOnly
        editorPane.makeReadOnly()
        IDEHelpers.showFileReadOnlyNotification()

      callback editorPane

    @createPane_ editorPane, paneOptions, file

    if emitChange
      change        =
        context     :
          file      :
            content : content
            path    : file.path
            machine :
              uid   : file.machine.uid

      @emitChange editorPane, change

    return editorPane


  createTerminal: (options) ->

    { appManager }   = kd.singletons
    frontApp         = appManager.getFrontApp()
    options.machine ?= frontApp.mountedMachine

    unless options.path
      workspaceData = frontApp.workspaceData or {}
      { rootPath, isDefault } = workspaceData

      if rootPath and not isDefault
        options.path = frontApp.workspaceData.rootPath

    terminalPane = new IDETerminalPane options
    @createPane_ terminalPane, { name: 'Terminal' }


  emitChange: (pane = {}, change = { context: {} }, type = 'NewPaneCreated') ->

    change.context.paneType = pane.options?.paneType or null
    change.context.paneHash = pane.hash or null

    change.type   = type
    change.origin = nick()

    if type in [ 'PaneRemoved', 'TabChanged' ] and pane.file
      change.context.file = path: pane.file.path

    @emit 'ChangeHappened', change


  createDrawingBoard: (paneHash) ->

    drawingPane = new IDEDrawingPane { hash: paneHash }
    @createPane_ drawingPane, { name: 'Drawing' }

    unless paneHash
      @emitChange  drawingPane, context: {}


  createPreview: (url) ->

    previewPane = new IDEPreviewPane { url }
    @createPane_ previewPane, { name: 'Browser' }

    previewPane.on 'LocationChanged', (newLocation) =>
      @updateStatusBar 'preview', newLocation

    @emitChange previewPane, context: { url }


  showView: (view) ->

    @createPane_ view, { name: 'Search Result' }


  updateStatusBar: (paneType, data) ->

    appManager = kd.getSingleton 'appManager'

    unless paneType
      subView  = @getActivePaneView()
      paneType = subView.getOptions().paneType  if subView

    unless data
      if paneType is 'editor'
        {file} = subView.getOptions()
        {ace}  = subView.aceView
        cursor = if ace.editor? then ace.editor.getCursorPosition() else row: 0, column: 0

        file.name = @trimUntitledFileName file.name

        data   = { file, cursor }

      else if paneType is 'terminal'
        machineName = subView.machine.getName()
        data   = { machineName }

      else if paneType is 'preview'
        data   = subView.getOptions().url or 'Enter a URL to browse...'

      else if paneType is 'drawing'
        data   = 'Use this panel to draw something'

      else if paneType is 'searchResult'
        {stats, searchText} = subView.getOptions()
        data = { stats, searchText }

    appManager.tell 'IDE', 'updateStatusBar', paneType, data


  removeOpenDocument: -> # legacy, should be reimplemented in ace bundle.


  getActivePaneView: -> return @tabView.getActivePane()?.view


  focusTab: ->

    pane = @getActivePaneView()
    return unless pane

    kd.utils.defer =>
      {paneType} = pane.getOptions()
      appManager = kd.getSingleton 'appManager'

      pane.setFocus? yes

      if paneType is 'editor'
        appManager.tell 'IDE', 'setFindAndReplaceViewDelegate'
        appManager.tell 'IDE', 'showFindAndReplaceViewIfNecessary'
      else
        appManager.tell 'IDE', 'hideFindAndReplaceView'

    if not @suppressChangeHandlers and not @isReadOnly
      @emitChange pane, context: {}, 'TabChanged'


  goToLine: ->

    @getActivePaneView().aceView.ace.showGotoLine()


  click: ->

    super

    appManager = kd.getSingleton 'appManager'

    appManager.tell 'IDE', 'setActiveTabView', @tabView
    appManager.tell 'IDE', 'setFindAndReplaceViewDelegate'

    @updateStatusBar()


  openSavedFile: (file, content) ->

      pane = @tabView.getActivePane()
      if pane.data instanceof FSFile and @isDummyFilePath pane.data.path
        @tabView.removePane @tabView.getActivePane()
      @openFile file, content



  openFile: (file, content, callback = kd.noop, emitChange) ->

    if @openFiles.indexOf(file) > -1
      editorPane = @switchToEditorTabByFile file
      callback editorPane
    else
      kallback = (pane) =>
        @openFiles.push file  if pane
        callback pane

      @createEditor file, content, kallback, emitChange


  switchToEditorTabByFile: (file) ->

    for pane, index in @tabView.panes when file is pane.getData()
      @tabView.showPaneByIndex index
      return editorPane = pane.view


  toggleFullscreen: ->

    @toggleClass 'fullscren'
    kd.getSingleton('windowController').notifyWindowResizeListeners()
    @isFullScreen = !@isFullScreen
    @holderView.setFullscreenHandleState @isFullScreen


  handlePaneRemoved: (pane) ->

    file = pane.getData()
    @openFiles.splice @openFiles.indexOf(file), 1
    @emitChange pane.view, context: {}, 'PaneRemoved'
    @emit 'PaneRemoved', pane


  getDummyFilePath: (uniquePath = yes) ->

    filePath = "localfile:/Untitled.txt"
    filePath += "@#{Date.now()}"  if uniquePath

    return filePath


  isDummyFilePath: (filePath) -> filePath.indexOf(@getDummyFilePath no) is 0


  openMachineTerminal: (machine) -> @createTerminal { machine }


  openMachineWebPage: (machine) -> @createPreview machine.ipAddress


  closeTabByFile: (file)  ->

    for pane in @tabView.panes when pane?.data is file
      pane.getOptions().aceView.ace.contentChanged = no # hook to avoid file close modal
      @tabView.removePane pane


  closeUntitledFileIfNotChanged: ->

    for pane in @tabView.panes when pane

      isFsFile = pane.data instanceof FSFile

      return unless isFsFile

      isLocal  = pane.data.path.indexOf('localfile:/') > -1
      isEmpty  = pane.view.getEditor()?.getSession()?.getValue() is '' # intentional `?` checks

      @tabView.removePane pane  if isLocal and isEmpty


  getPlusMenuItems: ->

    {appManager} = kd.singletons

    frontApp = appManager.getFrontApp()
    machine  = frontApp.mountedMachine

    sessions = machine?.getBaseKite().terminalSessions or []

    terminalSessions = {}
    activeSessions   = []

    frontApp.forEachSubViewInIDEViews_ 'terminal', (pane) =>
      activeSessions.push pane.remote.session  if pane.remote?

    sessions.forEach (session, i) =>
      isActive = session in activeSessions
      terminalSessions["Session (#{session[0..5]}) &nbsp"] =
        disabled          : isActive
        separator         : sessions.length is i
        children          :
          'Open'          :
            disabled      : isActive
            callback      : => @createTerminal { machine, session }
          'Terminate'     :
            callback      : => @terminateSession machine, session

    canTerminateSessions  = sessions.length > 0 and frontApp.amIHost

    terminalSessions["New Session"] =
      callback            : => @createTerminal { machine }
      separator           : canTerminateSessions

    if canTerminateSessions
      terminalSessions["Terminate all"] =
        callback          : => @terminateSessions machine

    items =
      'New File'          : callback : =>
         newFile = FSHelper.createFileInstance { path: @getDummyFilePath(), machine }
         kd.singletons.appManager.tell 'IDE', 'openFile', file: newFile
      'New Terminal'      : children : terminalSessions
      # 'New Browser'       : callback : => @createPreview()
      'New Drawing Board' :
        callback          : => @createDrawingBoard()
        separator         : yes
      'Split Vertically'  :
        callback          : -> frontApp.splitVertically()
      'Split Horizontally':
        callback          : -> frontApp.splitHorizontally()

    items['']           = # TODO: `type: 'separator'` also creates label, see: https://cloudup.com/c90pFQS_n6X
      type              : 'separator'

    label                 = if @isFullScreen then 'Exit Fullscreen' else 'Enter Fullscreen'
    items[label]          =
      callback            : @bound 'toggleFullscreen'

    return items


  createPlusContextMenu: ->

    return  if @isReadOnly

    offset      = @holderView.plusHandle.$().offset()
    offsetLeft  = offset.left - 133
    margin      = if offsetLeft >= -1 then -20 else 12
    placement   = 'top'
    options     =
      delegate  : this
      x         : Math.max 0, offsetLeft
      y         : offset.top + 30
      arrow     : { placement, margin }

    contextMenu = new KDContextMenu options, @getPlusMenuItems()

    contextMenu.once 'ContextMenuItemReceivedClick', -> contextMenu.destroy()


  closeSplitView: ->

    { frontApp } = kd.singletons.appManager
    frontApp.setActiveTabView @tabView

    frontApp.mergeSplitView()


  terminateSessions: (machine)->

    machine.getBaseKite().webtermKillSessions()

    .catch (err)->
      kd.warn "Failed to terminate sessions", err


  terminateSession: (machine, session) ->

    machine.getBaseKite().webtermKillSession {session}

    .catch (err)->
      kd.warn "Failed to terminate session, possibly it's already dead.", err


  dragover: (event) ->

    kd.utils.stopDOMEvent event


  drop: (event) ->

    selector  = '.kdtabhandle:not(.visible-tab-handle)'
    $target   = $(event.originalEvent.target).closest(selector)
    index     = $target.index()

    index = null  if index < 0

    kd.singletons.appManager.tell 'IDE', 'handleTabDropped', event, @parent, index


  handleWebtermCreated: (paneView) ->

    terminalPane   = paneView.view
    options        = terminalPane.getOptions()
    terminalHandle = @tabView.getHandleByPane paneView

    { machine, joinUser, fitToWindow } = options

    terminalPane.webtermView.on 'click', @bound 'click'

    if fitToWindow
      kd.utils.defer -> terminalPane.webtermView.triggerFitToWindow()

    @emit 'UpdateWorkspaceSnapshot'

    { remote : { session } } = terminalPane

    unless joinUser
      change =
        context   :
          session : session
          machine :
            uid   : machine.uid

      @emitChange terminalPane, change

    ###
    Rename terminal tab to terminal session name only if terminal has already been
    renamed before, i.e. session name isn't auto generated string which lenght is 24 symbols.
    If session name is auto generated string, leave terminal tab name with its default value 'Terminal'
    ###
    unless session.length is DEFAULT_SESSION_NAME_LENGTH
      terminalHandle.setTitle session


  handleTerminalRenamingRequested: (tabHandle, newTitle) ->

    paneView     = tabHandle.getOptions().pane
    terminalPane = paneView.view
    options      = terminalPane.getOptions()

    { machine } = options
    { remote : { session } } = terminalPane

    kite    = machine.getBaseKite()
    request =
      newName : newTitle
      oldName : session

    kite.init()
    .then ->
      kite.webtermRename request

    .then =>
      @renameTerminal paneView, machine, newTitle

      @emit 'UpdateWorkspaceSnapshot'

      change =
        context   :
          session : newTitle
          machine :
            uid   : machine.uid

      @emitChange terminalPane, change, 'TerminalRenamed'

    .catch (err) ->
      showErrorNotification err


  renameTerminal: (paneView, machine, newTitle) ->

    terminalPane = paneView.view
    terminalHandle = @tabView.getHandleByPane paneView

    terminalPane.setSession newTitle
    terminalHandle.setTitle newTitle

    machine.getBaseKite().fetchTerminalSessions()


toggleVisibility = (handle, state) ->
  el = handle.getElement()
  if state
  then el.classList.add 'in'
  else el.classList.remove 'in'


setupSplitHandleNotifier = (handle) ->

  splitTop = handle.getY()
  splitLeft = handle.getX()

  notifier = new ProximityNotifier
    handler: (event) ->
      { pageX, pageY } = event

      distX = Math.pow splitLeft - pageX, 2
      distY = Math.pow splitTop - pageY, 2
      dist  = Math.sqrt distX + distY

      return dist < HANDLE_PROXIMITY_DISTANCE

  notifier.on 'MouseInside', -> toggleVisibility handle, yes
  notifier.on 'MouseOutside', -> toggleVisibility handle

  handle.on 'KDObjectWillBeDestroyed', notifier.bound 'destroy'

  return notifier


