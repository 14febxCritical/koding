class CollaborativePreviewPane extends CollaborativePane

  constructor: (options = {}, data) ->

    super options, data

    @container.addSubView @previewPane = new PreviewPane @getOptions()

    {@previewer} = @previewPane

    if @isJoinedASession
      @workspaceRef.once "value", (snapshot) =>
        @openPathFromSnapshot snapshot

    @previewer.on "ViewerLocationChanged", => @saveUrl()

    @previewer.on "ViewerRefreshed",       => @saveUrl yes

    @workspaceRef.on "value", (snapshot)   => @openPathFromSnapshot snapshot

    @workspaceRef.onDisconnect().remove() if @amIHost

  openPathFromSnapshot: (snapshot) ->
    value = snapshot.val()
    @previewer.openPath value.url  if value?.url

  openUrl: (url) ->
    @previewer.openPath url
    @saveUrl yes

  saveUrl: (force) ->
    {path} = @previewer
    url    = unless force then path.replace(/\?.*/, "") else "#{path}?#{Date.now()}"

    @workspaceRef.child("url").set url
    @workspace.addToHistory
      message: "$0 opened #{url}"
      by     : KD.nick()
