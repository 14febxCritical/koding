class NFinderController extends KDViewController

  constructor:(options = {}, data)->

    {nickname}  = KD.whoami().profile

    options.view = new KDView cssClass : "nfinder file-container"
    treeOptions  = {}
    treeOptions.treeItemClass     = options.treeItemClass     or= NFinderItem
    treeOptions.nodeIdPath        = options.nodeIdPath        or= "path"
    treeOptions.nodeParentIdPath  = options.nodeParentIdPath  or= "parentPath"
    treeOptions.dragdrop          = options.dragdrop           ?= yes
    treeOptions.foldersOnly       = options.foldersOnly        ?= no
    treeOptions.hideDotFiles      = options.hideDotFiles       ?= no
    treeOptions.multipleSelection = options.multipleSelection  ?= yes
    treeOptions.addOrphansToRoot  = options.addOrphansToRoot   ?= no
    treeOptions.putDepthInfo      = options.putDepthInfo       ?= yes
    treeOptions.contextMenu       = options.contextMenu        ?= yes
    treeOptions.maxRecentFolders  = options.maxRecentFolders  or= 10
    treeOptions.useStorage        = options.useStorage         ?= no
    treeOptions.loadFilesOnInit   = options.loadFilesOnInit    ?= no
    treeOptions.delegate          = @

    super options, data

    TreeControllerClass = options.treeControllerClass or NFinderTreeController
    @treeController     = new TreeControllerClass treeOptions, []

    @appStorage = KD.getSingleton('appStorageController').storage 'Finder', '1.0a'

    if options.useStorage
      @appStorage.ready =>
        @treeController.on "file.opened", @bound 'setRecentFile'
        @treeController.on "folder.expanded", (folder)=>
          @setRecentFolder folder.path
        @treeController.on "folder.collapsed", ({path})=>
          @unsetRecentFolder path
          @stopWatching path

    @noVMFoundWidget = new VMMountStateWidget
    @cleanup()

  watchers: {}

  registerWatcher:(path, stopWatching)->
    @watchers[path] = stop: stopWatching

  stopAllWatchers:->
    (watcher.stop() for path, watcher of @watchers)
    @watchers = {}

  stopWatching:(pathToStop)->
    for path, watcher of @watchers  when (path.indexOf pathToStop) is 0
      watcher.stop()
      delete @watchers[path]

  loadView:(mainView)->
    mainView.addSubView @treeController.getView()
    mainView.addSubView @noVMFoundWidget
    @viewLoaded = yes

    @reset()  if @getOptions().loadFilesOnInit

    # temp hack, if page opens in develop section.
    @utils.wait 2500, =>
      KD.getSingleton("mainView").sidebar._windowDidResize()

  reset:->
    if @getOptions().useStorage
      @appStorage.ready => @loadVms()
    else
      @utils.defer => @loadVms()

  mountVms: (vms) ->
    return  unless Array.isArray vms
    @cleanup()
    @mountVm vm  for vm in vms

  loadVms:(vmNames, callback)->
    if vmNames then @mountVms vmNames
    else
      groupSlug  = KD.getSingleton("groupsController").getGroupSlug()
      groupSlug ?= KD.defaultSlug
      @appStorage.fetchValue "mountedVM", (vms)=>
        vms            or= {}
        vms[groupSlug] or= []
        if vms[groupSlug].length > 0
          @mountVms vms[groupSlug]
        else
          KD.remote.api.JVM.fetchVmsByContext {}, (err, vms)=>
            return callback? err  if err
            if not vms or vms.length is 0
              KD.getSingleton('vmController').fetchDefaultVmName (vm)=>
                if vm then @mountVms [vm]
                else @noVMFoundWidget.show()
            else
              @mountVms vms

  getVmNode:(vmName)->
    return null  unless vmName
    for path, vmItem of @treeController.nodes  when vmItem.data?.type is 'vm'
      return vmItem  if vmItem.data.vmName is vmName

  updateMountState:(vmName, state)->
    return  if KD.isGuest()
    groupSlug  = KD.getSingleton("groupsController").getGroupSlug()
    groupSlug ?= KD.defaultSlug
    @appStorage.fetchValue "mountedVM", (vms)=>
      vms or= {}
      vms[groupSlug] or= []
      items = vms[groupSlug]
      if state and vmName not in items
        items.push vmName
      else if not state and vmName in items
        items.splice items.indexOf(vmName), 1
      @appStorage.setValue "mountedVM", vms

  mountVm:(vm, fetchContent = yes)->
    return warn 'VM path required! e.g VMNAME[:PATH]'  unless vm

    [vmName, path] = vm.split ":"

    vmRoots = (@appStorage.getValue 'vmRoots') or {}
    pipedVm = @_pipedVm vmName
    path or= vmRoots[pipedVm] or "/home/#{KD.nick()}"

    if vmItem = @getVmNode vmName
      return warn "VM #{vmName} is already mounted!"

    @updateMountState vmName, yes

    @vms.push FSHelper.createFile
      name   : "#{path}"
      path   : "[#{vmName}]#{path}"
      type   : "vm"
      vmName : vmName

    @noVMFoundWidget.hide()
    @treeController.addNode @vms.last

    vmItem = @getVmNode vmName
    if fetchContent and vmItem
      # Without this, it fails to fetch Finder settings before creating
      # Fileitems o_0 FIXME ~ GG
      @utils.wait 1000, =>
        @treeController.expandFolder vmItem, (err)=>
          if err?.name is 'VMNotFoundError'
            return @unmountVm vmName
          @treeController.selectNode vmItem
          @utils.defer =>
            if @getOptions().useStorage then @reloadOldStructure vmName
        , yes

  unmountVm:(vmName)->
    vmItem = @getVmNode vmName
    return warn 'No such VM!'  unless vmItem

    @updateMountState vmName, no
    @stopWatching vmItem.data.path
    FSHelper.deregisterVmFiles vmName
    @treeController.removeNodeView vmItem
    @vms = @vms.filter (vmData)-> vmData isnt vmItem.data

    if @vms.length is 0
      @noVMFoundWidget.show()
      @emit 'EnvironmentsTabRequested'

  updateVMRoot:(vmName, path, callback)->
    return warn 'VM name and new path required!'  unless vmName or path

    @unmountVm vmName
    callback?()

    vmRoots = (@appStorage.getValue 'vmRoots') or {}
    pipedVm = @_pipedVm vmName
    vmRoots[pipedVm] = path
    @appStorage.setValue 'vmRoots', vmRoots

    @mountVm "#{vmName}:#{path}"

  cleanup:->
    @treeController.removeAllNodes()
    FSHelper.resetRegistry()
    @stopAllWatchers()
    @vms = []

  setRecentFile:({path})->
    recentFiles = @appStorage.getValue('recentFiles')
    recentFiles = []  unless Array.isArray recentFiles

    unless path in recentFiles
      if recentFiles.length is @treeController.getOptions().maxRecentFiles
        recentFiles.pop()
      recentFiles.unshift path

    @appStorage.setValue 'recentFiles', recentFiles.slice(0,10), =>
      @emit 'recentfiles.updated', recentFiles

  hideDotFiles:->
    for path, node of @treeController.nodes
      if node.getData().isHidden()
        @treeController.removeNodeView node

  showDotFiles:->

  setRecentFolder:(folderPath, callback)->
    recentFolders = @appStorage.getValue('recentFolders')
    recentFolders = []  unless Array.isArray recentFolders
    unless folderPath in recentFolders
      recentFolders.push folderPath
    recentFolders.sort (path)-> if path is folderPath then -1 else 0
    @appStorage.setValue 'recentFolders', recentFolders, callback

  unsetRecentFolder:(folderPath, callback)->
    recentFolders = @appStorage.getValue('recentFolders')
    recentFolders = []  unless Array.isArray recentFolders
    recentFolders = recentFolders.filter (path)->
      path.indexOf(folderPath) isnt 0
    recentFolders.sort (path)->
      if path is folderPath then -1 else 0
    @appStorage.setValue 'recentFolders', recentFolders, callback

  expandFolder:(folderPath, callback)->
    for path, node of @treeController.nodes
      if path is folderPath
        return @treeController.expandFolder node, callback
    callback {message:"Folder not exists: #{folderPath}"}

  reloadOldStructure:(vmName)->
    iterate = (folders, index)=>
      @expandFolder folders[index], (err)=>
        # if err then @unsetRecentFolder folders[index]
        index += 1
        iterate folders, index  if index <= folders.length
    folders = @appStorage.getValue('recentFolders') or []
    if vmName
      folders = folders.filter (folder)->
        folder.indexOf "[#{vmName}]" is 0
    iterate folders, 0

  _pipedVm:(vmName)-> vmName.replace /\./g, '|'

class VMMountStateWidget extends JView

  constructor:->
    super cssClass : 'no-vm-found-widget'

    @loader = new KDLoaderView
      size          : width : 20
      loaderOptions :
        speed       : 0.7
        FPS         : 24

    @warning = new KDCustomHTMLView
      partial : "There is no attached VM"

  pistachio:->
    """
    {{> @loader}}
    {{> @warning}}
    """

  showMessage:(message)->
    message or= """There is no VM attached to filetree, you can
                   attach or create one from environment menu below."""

    @warning.updatePartial message
    @warning.show()

    @loader.hide()

  show:->
    @setClass 'visible'
    @warning.hide()
    @loader.show()

    if KD.getSingleton("groupsController").getGroupSlug() is KD.defaultSlug
      @showMessage()

    # Not sure about it I guess only owners can create GroupVM?
    else if ("admin" in KD.config.roles) or ("owner" in KD.config.roles)
      group = KD.getSingleton("groupsController").getCurrentGroup()
      group.checkPayment (err, payments)=>
        warn err  if err
        if payments.length is 0
          @showMessage """There is no VM attached for this group, you can
                          attach one or you can <b>pay</b> and create
                          a new one from environment menu below."""
        else
          @showMessage """There is no VM attached for this group, you can
                          attach one or you can create a new one from
                          environment menu below."""

    else
      @showMessage """There is no VM for this group or not attached to
                      filetree yet, you can attach one from environment
                      menu below."""

  hide:->
    @unsetClass 'visible'
    @loader.hide()
