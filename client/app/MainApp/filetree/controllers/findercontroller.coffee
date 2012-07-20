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
    treeOptions.multipleSelection = options.multipleSelection  ?= yes
    treeOptions.addOrphansToRoot  = options.addOrphansToRoot   ?= no
    treeOptions.putDepthInfo      = options.putDepthInfo       ?= yes
    treeOptions.contextMenu       = options.contextMenu        ?= yes
    treeOptions.fsListeners       = options.fsListeners        ?= no
    treeOptions.initialPath       = options.initialPath        ?= "/Users/#{nickname}"
    treeOptions.maxRecentFolders  = options.maxRecentFolders  or= 10
    treeOptions.initDelay         = options.initDelay         or= 0
    treeOptions.useStorage        = options.useStorage         ?= no
    treeOptions.delegate          = @

    super options, data

    @kiteController = @getSingleton('kiteController')
    @treeController = new NFinderTreeController treeOptions, []

    @treeController.on "file.opened", (file)=> @setRecentFile file.path
    @treeController.on "folder.expanded", (folder)=> @setRecentFolder folder.path
    @treeController.on "folder.collapsed", (folder)=> @unsetRecentFolder folder.path

  loadView:(mainView)->

    mainView.addSubView @treeController.getView()
    @reset()

    if @treeController.getOptions().useStorage
      appManager.on "AppManagerOpensAnApplication", (appInst)=>
        if appInst instanceof StartTab12345 and not @defaultStructureLoaded
          @loadDefaultStructure()

  reset:->

    delete @_storage
    {initialPath} = @treeController.getOptions() # not used, fix this

    mount = if KD.isLoggedIn()
      {nickname}    = KD.whoami().profile
      FSHelper.createFile
        name        : nickname
        path        : "/Users/#{nickname}"
        type        : "mount"

    else
      FSHelper.createFile
        name        : "guest"
        path        : "/Users/guest"
        type        : "mount"
    @defaultStructureLoaded = no
    @treeController.initTree [mount]
    
    if @treeController.getOptions().useStorage
      @loadDefaultStructureTimer = @utils.wait @treeController.getOptions().initDelay, =>
        @loadDefaultStructure()

  loadDefaultStructure:->

    return if @defaultStructureLoaded
    @defaultStructureLoaded = yes
    @utils.killWait @loadDefaultStructureTimer

    return unless KD.isLoggedIn()    
    {nickname}     = KD.whoami().profile
    kiteController = KD.getSingleton('kiteController')
    @fetchStorage (storage)=>
      recentFolders = if storage.bucket?.recentFolders? and storage.bucket.recentFolders.length > 0
        storage.bucket.recentFolders
      else
        [
          "/Users/#{nickname}"
          "/Users/#{nickname}/Sites"
          "/Users/#{nickname}/Sites/#{nickname}.koding.com"
          "/Users/#{nickname}/Sites/#{nickname}.koding.com/website"
        ]

      timer = Date.now()
      mount = @treeController.nodes["/Users/#{nickname}"].getData()

      mount.emit "fs.fetchContents.started"
      kiteController.run
        withArgs  :
          command : "ls #{recentFolders.join(" ")} -lpva --group-directories-first --time-style=full-iso"
      , (err, response)=>
        if response
          files = FSHelper.parseLsOutput recentFolders, response
          @treeController.addNodes files
        log "#{(Date.now()-timer)/1000}sec !"
        # temp fix this doesn't fire in kitecontroller
        kiteController.emit "UserEnvironmentIsCreated"
        mount.emit "fs.fetchContents.finished"


  fetchStorage:(callback)->

    unless @_storage
      appManager.fetchStorage 'Finder', '1.0', (error, storage) =>
        callback @_storage = storage
    else
      callback @_storage

  setRecentFile:(filePath, callback)->

    @fetchStorage (storage)=>
      # recentFiles = storage.getAt('bucket.recentFiles') or []
      recentFiles = if storage.bucket?.recentFiles? then storage.bucket.recentFiles else []
      unless filePath in recentFiles
        recentFiles.pop() if recentFiles.length is @treeController.getOptions().maxRecentFiles
        recentFiles.unshift filePath

      storage.update {
        $set: 'bucket.recentFiles': recentFiles.slice(0,10)
      }, callback

  setRecentFolder:(folderPath, callback)->

    @fetchStorage (storage)=>

      recentFolders = if storage.bucket?.recentFolders? then storage.bucket.recentFolders else []

      unless folderPath in recentFolders
        recentFolders.push folderPath

      recentFolders.sort (path)-> if path is folderPath then -1 else 0

      storage.update {
        $set: 'bucket.recentFolders': recentFolders
      }, => #log "recentFolder set"

  unsetRecentFolder:(folderPath, callback)->

    @fetchStorage (storage)=>

      recentFolders = if storage.bucket?.recentFolders? then storage.bucket.recentFolders else []

      splicer = ->
        recentFolders.forEach (recentFolderPath)->
          if recentFolderPath.search(folderPath) > -1
            recentFolders.splice recentFolders.indexOf(recentFolderPath), 1
            splicer()
            return

      splicer()
      recentFolders.sort (path)-> if path is folderPath then -1 else 0

      storage.update {
        $set: 'bucket.recentFolders': recentFolders
      }, => #log "recentFolder unset"
