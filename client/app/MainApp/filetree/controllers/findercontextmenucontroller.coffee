class NFinderContextMenuController extends KDController


  ###
  CONTEXT MENU CREATION
  ###

  getMenuItems:(fileViews)->
    
    if fileViews.length > 1
      @getMutilpleItemMenu fileViews
    else
      [fileView] = fileViews
      switch fileView.getData().type
        when "file"    then @getFileMenu fileView
        when "folder"  then @getFolderMenu fileView
        when "mount"   then @getMountMenu fileView
        # when "section" then @getSectionMenu fileData

  getContextMenu:(fileViews, event)->
    
    @contextMenu.destroy() if @contextMenu
    items = @getMenuItems fileViews
    [fileView] = fileViews
    if items
      @contextMenu = new JContextMenu
        event    : event
        delegate : fileView
      , items
      @listenTo
        KDEventTypes       : "ContextMenuItemReceivedClick"
        listenedToInstance : @contextMenu
        callback           : (pubInst, contextMenuItem)=>
          @handleContextMenuClick fileView, contextMenuItem
      return @contextMenu
    else
      return no
  
  destroyContextMenu:->
    @contextMenu.destroy()

  handleContextMenuClick:(fileView, contextMenuItem)->
    
    @propagateEvent KDEventType : 'ContextMenuItemClicked', {fileView, contextMenuItem}

  getFileMenu:(fileView)->
    
    fileData = fileView.getData()
    
    items =
      'Open File'                 :
        action                    : 'openFile'
      'Open with...'              :
        separator                 : yes
        children                  :
          'Ace Editor'            :
            action                : 'openFile'
          'CodeMirror'            :
            action                : 'openFileWithCodeMirror'
          'Viewer'                :
            separator             : yes
            action                : 'previewFile'
          'Search the App Store'  :
            disabled              : yes
          'Contribute an Editor'  :
            disabled              : yes
      Delete                      :
        action                    : 'delete'
        separator                 : yes
      Rename                      :
        action                    : 'rename'
      Duplicate                   :
        action                    : 'duplicate'
      'Set permissions'           :
        children                  :
          customView              : new NSetPermissionsView {}, fileData
      Extract                     :
        action                    : 'extract'
      Compress                    :
        children                  :
          'as .zip'               :
            action                : 'zip'
          'as .tar.gz'            :
            action                : 'tarball'
      Download                    :
        separator                 : yes
        action                    : 'download'
        disabled                  : yes
      'New File'                  :
        action                    : 'createFile'
      'New Folder'                :
        action                    : 'createFolder'
      'Upload file...'            :
        disabled                  : yes
        action                    : 'upload'
      'Clone from Github...'      :
        disabled                  : yes
        action                    : 'gitHubClone'
    
    if 'archive' isnt @utils.getFileType @utils.getFileExtension fileData.name
      delete items.Extract
    else
      delete items.Compress

    return items


  getFolderMenu:(fileView)->
    
    fileData = fileView.getData()
    
    items =
      Expand                      :
        action                    : "expand"
        separator                 : yes
      Collapse                    :
        action                    : "collapse"
        separator                 : yes
      Delete                      :
        action                    : 'delete'
        separator                 : yes
      Rename                      :
        action                    : 'rename'
      Duplicate                   :
        action                    : 'duplicate'
      Compress                    : 
        children                  :
          'as .zip'               :
            action                : 'zip'
          'as .tar.gz'            :
            action                : 'tarball'
      'Set permissions'           :
        separator                 : yes
        children                  :
          customView              : new NSetPermissionsView {}, fileData
      'New File'                  :
        action                    : 'createFile'
      'New Folder'                :
        action                    : 'createFolder'
      'Upload file...'            :
        disabled                  : yes
        action                    : 'upload'
      'Clone from Github...'      :
        disabled                  : yes
        action                    : 'gitHubClone'
      Download                    : 
        disabled                  : yes
        action                    : "download"
        separator                 : yes
      Refresh                     :
        action                    : 'refresh'

    if fileView.expanded
      delete items.Expand
    else
      delete items.Collapse
      
    if fileView.getData().getExtension() is "kdapp"
      items.Refresh.separator   = yes
      items['Application menu'] =
        children                  :
          Compile                 :
            action                : "compile"
            separator             : yes
          "Publish to App Catalog":
            action                : "publish"

    return items


  getMountMenu:(fileView)->

    fileData = fileView.getData()
    
    items =
      Refresh                     :
        action                    : 'refresh'
        separator                 : yes
      Expand                      :
        action                    : "expand"
        separator                 : yes
      Collapse                    :
        action                    : "collapse"
        separator                 : yes
      'New File'                  :
        action                    : 'createFile'
      'New Folder'                :
        action                    : 'createFolder'
      'Upload file...'            :
        disabled                  : yes
        action                    : 'upload'

    if fileView.expanded
      delete items.Expand
    else
      delete items.Collapse

    return items

  getMutilpleItemMenu:(fileViews)->
    
    types =
      file    : no
      folder  : no
      mount   : no

    for fileView in fileViews
      types[fileView.getData().type] = yes
    
    if types.file and not types.folder and not types.mount
      return @getMultipleFileMenu fileViews

    else if not types.file and types.folder and not types.mount
      return @getMultipleFolderMenu fileViews

    items =

      Delete                      :
        action                    : 'delete'
        separator                 : yes
      Duplicate                   :
        action                    : 'duplicate'
      Compress                    :
        children                  :
          'as .zip'               :
            action                : 'zip'
          'as .tar.gz'            :
            action                : 'tarball'
      Download                    :
        disabled                  : yes
        action                    : 'download'
    
    return items
    
    
    
  getMultipleFolderMenu:(folderViews)->
    
    items =
      Expand                      :
        action                    : "expand"
        separator                 : yes
      Collapse                    :
        action                    : "collapse"
        separator                 : yes
      Delete                      :
        action                    : 'delete'
        separator                 : yes
      Duplicate                   :
        action                    : 'duplicate'
      'Set permissions'           :
        children                  :
          customView              : (new NSetPermissionsView {}, {mode : "000", type : "multiple"})
      Compress                    :
        children                  :
          'as .zip'               :
            action                : 'zip'
          'as .tar.gz'            :
            action                : 'tarball'
      Download                    :
        disabled                  : yes
        action                    : 'download'

    allCollapsed = allExpanded = yes
    for folderView in folderViews
      if folderView.expanded then allCollapsed = no
      else allExpanded = no

    delete items.Collapse if allCollapsed
    delete items.Expand if allExpanded

    return items

  getMultipleFileMenu:(fileViews)->

    items =
      'Open Files'                :
        action                    : 'openFile'
      'Open with...'              :
        separator                 : yes
        children                  :
          'Ace Editor'            :
            action                : 'openFile'
          'CodeMirror'            :
            action                : 'openFileWithCodeMirror'
          'Viewer'                :
            separator             : yes
            action                : 'previewFile'
          'Search the App Store'  :
            disabled              : yes
          'Contribute an Editor'  :
            disabled              : yes
      'Delete all'                :
        action                    : 'delete'
        separator                 : yes
      Duplicate                   :
        action                    : 'duplicate'
      'Set permissions'           :
        children                  :
          customView              : (new NSetPermissionsView {}, {mode : "000"})
      Compress                    :
        separator                 : yes
        children                  :
          'as .zip'               :
            action                : 'zip'
          'as .tar.gz'            :
            action                : 'tarball'
      Download                    :
        disabled                  : yes
        action                    : 'download'
    
    return items
    
    
# this is shorter but needs coffee script update

# 'Open File'                 : action : 'openFile'
# 'Open with...'              :
#   children                  :
#     'Ace Editor'            : action : 'openFile'
#     'CodeMirror'            : action : 'openFileWithCodeMirror'
#     'Viewer'                : action : 'previewFile'
#     divider                 : yes
#     'Search the App Store'  : disabled : yes
#     'Contribute an Editor'  : disabled : yes
# divider                     : yes
# Delete                      : action : 'delete'
# divider                     : yes
# Rename                      : action : 'rename'
# Duplicate                   : action : 'duplicate'
# 'Set permissions'           :
#   children                  :
#     customView              : KDView
# Extract                     : action : 'extract'
# Compress                    :
#   children                  :
#     'as .zip'               :
#       action                : 'zip'
#     'as .tar.gz'            :
#       action                : 'tarball'
# Download                    : action : 'download'
# divider                     : yes
# 'New File'                  : action : 'createFile'
# 'New Folder'                : action : 'createFolder'
# 'Upload file...'            : action : 'upload', disabled : yes
# 'Clone from Github...'      : action : 'gitHubClone', disabled : yes
