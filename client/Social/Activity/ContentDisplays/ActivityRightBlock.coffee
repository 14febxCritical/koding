class ActivityRightBase extends JView

  constructor:(options={}, data)->

    super options, data

    @tickerController = new KDListViewController
      startWithLazyLoader : yes
      lazyLoaderOptions   : partial : ''
      viewOptions         :
        type              : "activities"
        cssClass          : "activities"
        itemClass         : @itemClass

    @tickerListView = @tickerController.getView()


  renderItems: (err, items=[])->

    @tickerController.hideLazyLoader()
    @tickerController.addItem item for item in items  unless err


  pistachio:->
    """
    <div class="right-block-box">
      <h3>#{@getOption 'title'}{{> @showAllLink}}</h3>
      {{> @tickerListView}}
    </div>
    """

class ActiveUsers extends ActivityRightBase


  constructor:(options={}, data)->

    @itemClass       = MembersListItemView
    options.title    = "Active users"
    options.cssClass = "active-users"

    super options, data

    @showAllLink = new KDCustomHTMLView
      tagName : "a"
      partial : "show all"
      cssClass: "show-all-link hidden"
      click   : (event) ->
        KD.singletons.router.handleRoute "/Members"
        KD.mixpanel "Show all members, click"
    , data

    KD.remote.api.ActiveItems.fetchUsers {}, @bound 'renderItems'

class ActiveTopics extends ActivityRightBase

  constructor:(options={}, data)->

    @itemClass       = ActiveTopicItemView
    options.title    = "Popular topics"
    options.cssClass = "active-topics"

    super options, data

    @showAllLink = new KDCustomHTMLView
    {entryPoint} = KD.config

    if entryPoint?.slug and entryPoint?.type is "group" then group = entryPoint.slug else group = "koding"

    @showAllLink = new KDCustomHTMLView
      tagName : "a"
      partial : "show all"
      cssClass: "show-all-link"
      click   : (event) ->
        if group is "koding" then route = "/Topics" else route = "/#{group}/Topics"
        KD.singletons.router.handleRoute route
        KD.mixpanel "Show all topics, click"
    , data

    KD.remote.api.ActiveItems.fetchTopics {group}, @bound 'renderItems'


class GroupDescription extends KDView

  constructor:(options={}, data)->
    super options, data

    {groupsController} = KD.singletons
    groupsController.ready =>
      group = groupsController.getCurrentGroup()

      @innerContaner = new KDCustomHTMLView cssClass : "right-block-box"

      @titleView = new KDCustomHTMLView
        tagName  : "h3"
        partial  : "#{group.title} Group"

      @bodyView = new KDCustomHTMLView
        tagName  : "p"
        partial  : group.body or ""
        cssClass : "group-description"

      @innerContaner.addSubView @titleView
      @innerContaner.addSubView @bodyView
      @addSubView @innerContaner

  viewAppended:JView::viewAppended


class GroupMembers extends ActivityRightBase

  constructor:(options={}, data)->
    @itemClass       = GroupMembersListItemView
    options.title    = "Group members"
    options.cssClass = "group-members"

    super options, data

    if entryPoint?.slug and entryPoint?.type is "group" then groupSlug = entryPoint.slug else groupSlug = "koding"

    @showAllLink = new KDCustomHTMLView
      tagName    : "a"
      partial    : "See All"
      cssClass   : "show-all-link"
      click      : (event) ->
        KD.singletons.router.handleRoute "/#{groupSlug}/Members"
        KD.mixpanel "Show all members, click"
    , @getData()

    {groupsController} = KD.singletons
    groupsController.ready =>
      groupsController.getCurrentGroup().fetchMembersFromGraph limit : 12, @bound 'renderItems'


class GroupMembersListItemView extends KDListItemView

  constructor: (options = {}, data) ->
    super options, data
    @avatar      = new AvatarView
      size       : width : 60, height : 60
      showStatus : yes
    , @getData()
    @addSubView @avatar

  viewAppended:JView::viewAppended
