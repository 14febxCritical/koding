class DashboardAppView extends JView

  constructor:(options={}, data)->

    options.cssClass or= "content-page"
    data or= KD.getSingleton("groupsController").getCurrentGroup()
    super options, data

    @header = new HeaderViewSection type : "big", title : "Group Dashboard"
    @nav    = new CommonInnerNavigation
    @tabs   = new KDTabView
      cssClass            : 'dashboard-tabs'
      hideHandleContainer : yes
    , data

    @setListeners()
    @once 'viewAppended', =>
      @header.hide()
      @nav.hide()
      group = KD.getSingleton("groupsController").getCurrentGroup()
      group.canEditGroup (err, success)=>
        if err or not success
          {entryPoint} = KD.config
          KD.getSingleton('router').handleRoute "/Activity", { entryPoint }
        else
          @header.show()
          @nav.show()
          @createTabs()
          @_windowDidResize()

    @searchWrapper = new KDCustomHTMLView
      tagName  : 'section'
      cssClass : 'searchbar'

    @search = new KDHitEnterInputView
      placeholder  : "Search..."
      name         : "searchInput"
      cssClass     : "header-search-input"
      type         : "text"
      focus        : =>
        @tabs.showPaneByName "Members"  unless @tabs.getActivePane().name is 'Invitations'
      callback     : =>
        if @tabs.getActivePane().name is 'Invitations'
          pane = @tabs.getActivePane()
        else
          pane = @tabs.getPaneByName "Members"
        {mainView} = pane
        return unless mainView
        mainView.emit 'SearchInputChanged', @search.getValue()
        @search.focus()
      keyup        : =>
        return unless @search.getValue() is ""
        if @tabs.getActivePane().name is 'Invitations'
          pane = @tabs.getActivePane()
        else
          pane = @tabs.getPaneByName "Members"
        {mainView} = pane
        return unless mainView
        mainView.emit 'SearchInputChanged', ''

    @searchIcon = new KDCustomHTMLView
      tagName  : 'span'
      cssClass : 'icon search'

    @searchWrapper.addSubView @search
    @searchWrapper.addSubView @searchIcon
    @header.addSubView @searchWrapper

    @on "groupSettingsUpdated", (group)->
      @setData group
      @createTabs()

  setListeners:->

    @listenWindowResize()
    @nav.on "viewAppended", =>
      @navController = @nav.setListController
        itemClass : ListGroupShowMeItem
      ,
        title     : "SHOW ME"
        items     : []

      @nav.addSubView @navController.getView()

    @nav.on "NavItemReceivedClick", ({title})=> @tabs.showPaneByName title
    @tabs.on "PaneDidShow", (pane)=> @navController.selectItemByName pane.name

  createTabs:->

    data = @getData()
    KD.getSingleton('appManager').tell 'Dashboard', 'fetchTabData', (tabData)=>
      navItems = []
      for {name, hiddenHandle, viewOptions, kodingOnly}, i in tabData
        viewOptions.data = data
        viewOptions.options = delegate : this  if name is 'Settings'
        hiddenHandle = hiddenHandle? and data.privacy is 'public'
        @tabs.addPane (pane = new KDTabPaneView {name, viewOptions}), i is 0

        # Push all items, however if it has 'kodingOnly' push only when the group is really 'koding'
        if not kodingOnly or data.slug is 'koding'
          navItems.push {title: name, type: if hiddenHandle then 'hidden' else null}


      @navController.replaceAllItems navItems
      @navController.selectItem @navController.itemsOrdered.first

  _windowDidResize:->
    contentHeight = @getHeight() - @header.getHeight()
    @$('>section, >aside').height contentHeight

  pistachio:->
    """
      {{> @header}}
      <aside class='fl'>
        {{> @nav}}
      </aside>
      <section class='right-overflow'>
        {{> @tabs}}
      </section>
    """
