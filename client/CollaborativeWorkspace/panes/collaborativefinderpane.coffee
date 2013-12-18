# TODO: Should implement non-collaborative finder
# TODO: Should extend this class from NonCollab one.

class CollaborativeFinderPane extends CollaborativePane

  constructor: (options = {}, data) ->

    options.cssClass = "finder-pane nfinder file-container"

    super options, data

    @finderController = new NFinderController
      nodeIdPath          : "path"
      nodeParentIdPath    : "parentPath"
      contextMenu         : yes
      useStorage          : no
      treeControllerClass : CollaborativeFinderTreeController

    @container?.destroy()
    @finder = @container = @finderController.getView()

    @workspaceRef.on "value", (snapshot) =>
      clientData = snapshot.val()?.ClientWantsToInteractWithRemoteFileTree
      if clientData
        path             = "[#{clientData.vmName}]#{clientData.path}"
        {treeController} = @finderController
        nodeView         = treeController.nodes[path]
        nodeView.user    = clientData.user

        treeController.openItem nodeView, clientData
        @finderController.treeController.syncInteraction()

    @finderController.on "FileTreeInteractionDone", (files) =>
      @syncContent files

    @finderController.on "OpenedAFile", (file, content) =>
      editorPane = @panel.getPaneByName @getOptions().editor
      unless editorPane
        for pane in @panel.panes
          if pane instanceof CollaborativeEditorPane or pane instanceof CollaborativeTabbedEditorPane
            editorPane = pane

      return  warn "could not find an editor instance to set file content" unless editorPane

      editorPane.openFile file, content

    @workspaceRef.onDisconnect().remove()  if @workspace.amIHost()

    @finderController.reset()  unless @workspace.getOptions().playground

    @finderController.treeController.on "HistoryItemCreated", (historyItem) =>
      @workspace.addToHistory historyItem

  syncContent: (files) ->
    @workspaceRef.set { files }


class CollaborativeFinderTreeController extends NFinderTreeController

  addNodes: (nodes) ->
    super nodes
    @syncInteraction()

  openItem: (nodeView, clientData) ->
    nodeData = nodeView.getData()
    keyword  = "opened"
    user     = if clientData then clientData.requestedBy else KD.nick()
    {name, path, type} = nodeData

    if type is "folder"
      isExpanded = @nodes[nodeData.path].expanded
      keyword    = if isExpanded then "collapsed" else "expanded"

    @emit "HistoryItemCreated",
      message  : "#{user} #{keyword} #{nodeData.name}"
      data     : { name, path, type }

    super nodeView

  getSnapshot: ->
    snapshot = []

    for own path, node of @nodes
      nodeData = node.data

      snapshot.push
        path   : FSHelper.plainPath path
        type   : nodeData.type
        vmName : nodeData.vmName
        name   : nodeData.name

    return snapshot

  syncInteraction: ->
    @getDelegate().emit "FileTreeInteractionDone", @getSnapshot()

  toggleFolder: (nodeView, callback) ->
    super nodeView, @bound "syncInteraction"

  openFile: (nodeView) ->
    return unless nodeView
    file = nodeView.getData()
    file.fetchContents (err, contents) =>
      @getDelegate().emit "OpenedAFile", file, contents
