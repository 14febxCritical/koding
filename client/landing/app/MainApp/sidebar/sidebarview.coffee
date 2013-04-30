class Sidebar extends JView

  constructor:->

    super

    account           = KD.whoami()
    {profile}         = account
    @_onDevelop       = no
    @_finderExpanded  = no
    @_popupIsActive   = no

    @avatar = new AvatarView
      tagName    : "div"
      cssClass   : "avatar-image-wrapper"
      size       :
        width    : 160
        height   : 76
    , account

    @avatarAreaIconMenu = new AvatarAreaIconMenu
      delegate     : @

    @navController = new NavigationController
      view           : new NavigationList
        type         : "navigation"
        itemClass    : NavigationLink
      wrapper        : no
      scrollView     : no
    , navItems

    @nav = @navController.getView()

    @footerMenuController = new NavigationController
      view           : new NavigationList
        type         : "footer-menu"
        itemClass    : FooterMenuItem
      wrapper        : no
      scrollView     : no
    , footerMenuItems

    @footerMenu = @footerMenuController.getView()

    @finderHeader = new KDCustomHTMLView
      tagName   : "h2"
      pistachio : "{{#(profile.nickname)}}.#{location.hostname}"
    , account

    @finderResizeHandle = new SidebarResizeHandle
      cssClass  : "finder-resize-handle"

    @finderController = new NFinderController
      useStorage        : yes
      addOrphansToRoot  : no

    @finder = @finderController.getView()

    @finderBottomControlsController = new KDListViewController
      view        : new FinderBottomControls
      wrapper     : no
      scrollView  : no
    , bottomControlsItems

    @finderBottomControls = @finderBottomControlsController.getView()

    @finderBottomControlPin = new KDToggleButton
      cssClass     : "finder-bottom-pin"
      iconOnly     : yes
      defaultState : "hide"
      states       : [
        title      : "show"
        iconClass  : "up"
        callback   : (callback)=>
          @showBottomControls()
          callback?()
      ,
        title      : "hide"
        iconClass  : "down"
        callback   : (callback)=>
          @hideBottomControls()
          callback?()
      ]

    KD.registerSingleton "finderController", @finderController
    @listenWindowResize()

    # @statusLEDs = new StatusLEDView
    @statusLEDs = new KDView
      cssClass : 'status-leds'

    @virtualizationButtons = new VirtualizationControls

  resetAdminNavController:->
    @utils.wait 1000, =>
      @adminNavController.removeAllItems()
      if KD.isLoggedIn()
        KD.whoami().fetchRole? (err, role)=>
          if role is "super-admin"
            @adminNavController.instantiateListItems adminNavItems.items

  setListeners:->

    mainController                 = @getSingleton "mainController"
    mainViewController             = @getSingleton "mainViewController"
    mainView                       = @getSingleton "mainView"
    {@contentPanel, @sidebarPanel} = mainView
    $fp                            = @$('#finder-panel')
    cp                             = @contentPanel
    @wc                            = @getSingleton "windowController"
    fpLastWidth                    = null

    mainController.on "AvatarPopupIsActive",   => @_popupIsActive = yes
    mainController.on "AvatarPopupIsInactive", => @_popupIsActive = no

    @finderResizeHandle.on "ClickedButNotDragged", =>
      unless fpLastWidth
        fpLastWidth = parseInt $fp.css("width"), 10
        cp.$().css left : 65, width : @wc.winWidth - 65
        @utils.wait 300, -> $fp.css "width", 13
      else
        fpLastWidth = 208 if fpLastWidth < 100
        $fp.css "width", fpLastWidth
        cpWidth = @wc.winWidth - 52 - fpLastWidth
        cp.$().css left : 52 + fpLastWidth, width : cpWidth
        cp.emit "ViewResized", {newWidth : cpWidth, unit: "px"}
        fpLastWidth = null
      @finderResizeHandle.$().css left: ''

    @finderResizeHandle.on "DragStarted", (e, dragState)=>
      cp._left  = parseInt cp.$().css("left"), 10
      cp._left  = parseInt cp.$().css("left"), 10
      @_fpWidth = parseInt $fp.css("width"), 10
      cp._width = parseInt @wc.winWidth - 52 - @_fpWidth, 10
      cp.unsetClass "transition"

    @finderResizeHandle.on "DragFinished", (e, dragState)=>
      delete cp._left
      delete cp._width
      delete @_fpWidth
      unless @finderResizeHandle._dragged
        @finderResizeHandle.emit "ClickedButNotDragged"
      else
        fpLastWidth = null
      delete @finderResizeHandle._dragged
      cp.setClass "transition"

    @finderResizeHandle.on "DragInAction", (x, y)=>
      @finderResizeHandle._dragged = yes
      newFpWidth = @_fpWidth + x
      return @finderResizeHandle.$().css left: '' if newFpWidth < 13
      cpWidth = cp._width - x
      cp.$().css left : cp._left + x, width : cpWidth
      @finderResizeHandle.$().css left: ''
      $fp.css "width", newFpWidth
      cp.emit "ViewResized", {newWidth : cpWidth, unit: "px"}

    # exception - Sinan, Jan 2013
    # we bind this with jquery directly bc #main-nav is no KDView but just HTML
    @$('#main-nav').on "mouseenter", @bound "animateLeftNavIn"
    @$('#main-nav').on "mouseleave", @bound "animateLeftNavOut"

    mainViewController.on "UILayoutNeedsToChange", @bound "changeLayout"

  changeLayout:(options)->

    {type, hideTabs} = options
    windowController = @getSingleton 'windowController'

    @$finderPanel       or= @$('#finder-panel')
    @$avatarPlaceholder or= @$('.avatar-placeholder')
    @_onDevelop           = type is 'develop'

    width = switch type
      when 'full', 'social'
        @$finderPanel.removeClass "expanded"
        @$avatarPlaceholder.removeClass "collapsed"
      when 'develop'
        @$finderPanel.addClass "expanded"
        @$avatarPlaceholder.addClass "collapsed"

    @utils.wait 300, => @emit "NavigationPanelWillCollapse"

  viewAppended:->
    super
    @setListeners()

  pistachio:->

    """
    <div id="main-nav">
      <div class="avatar-placeholder">
        <div id="avatar-area">
          {{> @avatar}}
        </div>
      </div>
      {{> @avatarAreaIconMenu}}
      {{> @statusLEDs}}
      {{> @nav}}
      {{> @footerMenu}}
    </div>
    <div id='finder-panel'>
      {{> @finderResizeHandle}}
      <div id='finder-header-holder'>
        {{> @finderHeader}}
        {{> @virtualizationButtons}}
      </div>
      <div id='finder-holder'>
        {{> @finder}}
      </div>
      <div id='finder-bottom-controls'>
        {{> @finderBottomControlPin}}
        <span class='horizontal-handler'></span>
        {{> @finderBottomControls}}
      </div>
    </div>
    """
  _mouseenterTimeout = null
  _mouseleaveTimeout = null

  animateLeftNavIn:->
    return if $('body').hasClass("dragInAction")
    @utils.killWait _mouseleaveTimeout if _mouseleaveTimeout
    _mouseenterTimeout = @utils.wait 200, =>
      @_mouseentered = yes
      @expandNavigationPanel() if @_onDevelop

  animateLeftNavOut:->
    return if @_popupIsActive or $('body').hasClass("dragInAction")
    @utils.killWait _mouseenterTimeout if _mouseenterTimeout
    _mouseleaveTimeout = @utils.wait 200, =>
      if @_mouseentered and @_onDevelop
        @collapseNavigationPanel()

  expandNavigationPanel:->

    @$('.avatar-placeholder').removeClass "collapsed"
    @$('#finder-panel').removeClass "expanded"
    if parseInt(@contentPanel.$().css("left"), 10) < 174
      @contentPanel.setClass "mouse-on-nav"
    @utils.wait 300, => callback?()

  collapseNavigationPanel:(callback)->

    @$('.avatar-placeholder').addClass "collapsed"
    @$('#finder-panel').addClass "expanded"
    @contentPanel.unsetClass "mouse-on-nav"
    @utils.wait 300, =>
      callback?()
      @emit "NavigationPanelWillCollapse"

  hideBottomControls:->
    @$('#finder-bottom-controls').addClass 'go-down'
    @$("#finder-holder").height @getHeight() - @$("#finder-header-holder").height() - 27

  showBottomControls:->
    @$('#finder-bottom-controls').removeClass 'go-down'
    # @$("#finder-holder").height @getHeight() - @$("#finder-header-holder").height() - 27

  _windowDidResize:->

    {winWidth} = @getSingleton('windowController')
    # if KD.isLoggedIn()
    #   if @contentPanel.$().hasClass "with-finder"
    #     @contentPanel.setWidth winWidth - parseInt(@$('#finder-panel').css("width"), 10) - 52
    #   else
    #     @contentPanel.setWidth winWidth - 160
    # else
    #   @contentPanel.setWidth winWidth

    bottomListHeight = @$("#finder-bottom-controls").height() or 109
    @$("#finder-holder").height @getHeight() - @$("#finder-header-holder").height() - bottomListHeight

  navItems =
    # temp until groups are implemented
    do ->
      if location.hostname is "koding.com"
        id        : "navigation"
        title     : "navigation"
        items     : [
          { title : "Home",           path : "/Activity" }
          { title : "Activity",       path : "/Activity" }
          { title : "Topics",         path : "/Topics" }
          { title : "Members",        path : "/Members" }
          { title : "Develop",        path : "/Develop", loggedIn: yes }
          { title : "Apps",           path : "/Apps" }
          { type  : "separator" }
          { title : "Invite Friends", type : "account", loggedIn: yes }
          { title : "Account",        path : "/Account", type : "account", loggedIn  : yes }
          { title : "Logout",         path : "/Logout",  type : "account", loggedIn  : yes }
          { title : "Login",          path : "/Login",   type : "account", loggedOut : yes }
        ]
      else
        id        : "navigation"
        title     : "navigation"
        items     : [
          { title : "Home",           path : "/Activity" }
          { title : "Activity",       path : "/Activity" }
          { title : "Topics",         path : "/Topics" }
          { title : "Members",        path : "/Members" }
          { title : "Groups",         path : "/Groups" }
          { title : "Develop",        path : "/Develop",  loggedIn: yes }
          { title : "Apps",           path : "/Apps" }
          { type  : "separator" }
          { title : "Invite Friends", type : "account", loggedIn: yes }
          { title : "Account",        path : "/Account", type : "account", loggedIn  : yes }
          { title : "Logout",         path : "/Logout",  type : "account", loggedIn  : yes }
          { title : "Login",          path : "/Login",   type : "account", loggedOut : yes }
        ]

  bottomControlsItems =
    id : "finder-bottom-controls"
    items : [
      {
        title   : "Launch Terminal", icon : "terminal",
        appPath : "WebTerm", isWebTerm : yes
      }
      # {
      #   title   : "Manage Remotes", icon : "remotes",
      #   action  : "manageRemotes"
      # }
      # {
      #   title   : "Manage Databases", icon : "databases",
      #   action  : "manageDatabases"
      # }
      { title   : "Add Resources",      icon : "resources" }
      { title   : "Settings",           icon : "cog" }
      {
        title   : "Keyboard Shortcuts", icon : "shortcuts",
        action  : "showShortcuts"
      }
    ]

  adminNavItems =
    id    : "admin-navigation"
    title : "admin-navigation"
    items : [
      # { title : "Kite selector", loggedIn : yes, callback : -> new KiteSelectorModal }
      {
        title    : "Admin Panel",
        loggedIn : yes,
        callback : -> new AdminModal
      }
    ]

  footerMenuItems =
    id    : "footer-menu"
    title : "footer-menu"
    items : [
      {
        title    : "Help",
        callback : ->
          @getSingleton('mainController').emit "ShowInstructionsBook"
      }
      {
        title    : "About",
        callback : -> @showAboutDisplay()
      }
      {
        title    : "Chat",
        loggedIn : yes,
        callback : ->
          # @getSingleton('bottomPanelController').emit "TogglePanel", "chat"
          # unless location.hostname is "localhost"
          new KDNotificationView title : "Coming soon..."
      }
    ]
