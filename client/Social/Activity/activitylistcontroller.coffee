class ActivityListController extends KDListViewController

  {dash} = Bongo

  constructor:(options={}, data)->

    viewOptions = options.viewOptions or {}
    viewOptions.cssClass      or= 'activity-related'
    viewOptions.comments       ?= yes
    viewOptions.itemClass     or= options.itemClass
    options.view              or= new KDListView viewOptions, data
    options.startWithLazyLoader = yes
    options.lazyLoaderOptions   = partial : ''
    options.showHeader         ?= yes
    options.noItemFoundWidget or= new KDCustomHTMLView
      cssClass : "lazy-loader hidden"
      partial  : "There is no activity."

    # this is regressed until i touch this again. - SY
    # options.noMoreItemFoundWidget or= new KDCustomHTMLView
    #   cssClass : "lazy-loader"
    #   partial  : "There is no more activity."

    super options, data

    @resetList()
    @hiddenItems = []
    @_state      = 'public'

    groupController = KD.getSingleton("groupsController")
    groupController.on "MemberJoinedGroup", (member) =>
      @updateNewMemberBucket member.member

    groupController.on "FollowHappened", (info) =>
      {follower, origin} = info
      @updateFollowerBucket follower, origin

    groupController.on "PostIsCreated", (post) =>

      subject  = @prepareSubject post
      instance = @addItem subject, 0

      if @activityHeader?.liveUpdateToggle.getState().title is 'broken' and\
         not @isMine subject

        instance.hide()
        @hiddenItems.push instance
        @activityHeader.newActivityArrived()
        return


  prepareSubject:(post)->
    {subject} = post
    subject = KD.remote.revive subject
    @bindItemEvents subject
    return subject

  resetList:-> @lastItemTimeStamp = null

  loadView:(mainView)->

    data = @getData()
    mainView.addSubView @activityHeader = new ActivityListHeader
      cssClass : 'feeder-header clearfix'

    @activityHeader.hide()  unless @getOptions().showHeader

    @activityHeader.on "UnhideHiddenNewItems", =>
      @unhideNewHiddenItems()

    @emit "ready"
    KD.getSingleton("activityController").clearNewItemsCount()

    super

  isMine:(activity)->
    id = KD.whoami().getId()
    id? and id in [activity.originId, activity.anchor?.id]

  listActivities:(activities)->
    @hideLazyLoader()
    return  unless activities.length > 0
    activityIds = []
    queue = []

    activities.forEach (activity)=>
      queue.push =>
        @addItem activity
        activityIds.push activity._id
        queue.fin()

    dash queue, =>

      @checkIfLikedBefore activityIds

      @lastItemTimeStamp or= Date.now()

      for obj in activities
        @bindItemEvents obj
        objectTimestamp = (new Date(obj.meta.createdAt)).getTime()
        if objectTimestamp < @lastItemTimeStamp
          @lastItemTimeStamp = objectTimestamp

  checkIfLikedBefore:(activityIds)->
    KD.remote.api.CActivity.checkIfLikedBefore activityIds, (err, likedIds)=>
      for activity in @getListView().items when activity.data.getId().toString() in likedIds
        likeView = activity.subViews.first.actionLinks?.likeView
        if likeView
          likeView.setClass "liked"
          likeView._currentState = yes

  addItem:(activity, index, animation) ->
    dataId = activity.getId?() or activity._id
    if dataId?
      if @itemsIndexed[dataId]
        log "duplicate entry", activity.bongo_?.constructorName, dataId
      else
        @itemsIndexed[dataId] = activity
        super activity, index, animation

  unhideNewHiddenItems: ->

    @hiddenItems.forEach (item)=> log item; item.show()

    @hiddenItems = []

    unless KD.getSingleton("router").getCurrentPath() is "/Activity"
      KD.getSingleton("activityController").clearNewItemsCount()

  instantiateListItems:(items)->
    newItems = super
    @checkIfLikedBefore (item.getId()  for item in items)
    return newItems

  bindItemEvents: (item) ->
    item.on "TagsUpdated", (tags) ->
      item.tags = KD.remote.revive tags
