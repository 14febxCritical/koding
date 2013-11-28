class MainViewController extends KDViewController

  constructor:->

    super

    {repeat, killRepeat} = KD.utils
    {body}           = document
    mainView         = @getView()
    mainController   = KD.singleton 'mainController'
    appManager       = KD.singleton 'appManager'
    display          = KD.singleton 'display'
    @registerSingleton 'mainViewController', this, yes
    @registerSingleton 'mainView', mainView, yes

    warn "FIXME Add tell to Login app ~ GG @ kodingrouter (if needed)"
    # mainController.on 'accountChanged.to.loggedIn', (account)->
    #   mainController.loginScreen.hide()

    appManager.on 'AppIsBeingShown', (controller)=>
      @setBodyClass KD.utils.slugify controller.getOption 'name'

    display.on 'ContentDisplayWantsToBeShown', do =>
      type = null
      (view)=>
        if type = view.getOption 'type'
          @setBodyClass type

    mainController.on "ShowInstructionsBook", (index)->
      book = mainView.addBook()
      book.fillPage index
      book.checkBoundaries()

    mainController.on "ToggleChatPanel", -> mainView.chatPanel.toggle()

    if KD.checkFlag 'super-admin'
    then KDView.setElementClass body, 'add', 'super'
    else KDView.setElementClass body, 'remove', 'super'

    mainViewController = this
    window.onscroll = do ->
      threshold     = 50
      lastScroll    = 0
      currentHeight = 0

      (event)->
        el = document.body
        {scrollHeight, scrollTop} = el

        current = scrollTop + window.innerHeight
        if current > scrollHeight - threshold
          return if lastScroll > 0
          appManager.getFrontApp()?.emit "LazyLoadThresholdReached"
          lastScroll    = current
          currentHeight = scrollHeight
        else if current < lastScroll then lastScroll = 0

        if scrollHeight isnt currentHeight then lastScroll = 0

  setBodyClass: do ->

    previousClass = null

    (name)->

      {body} = document
      KDView.setElementClass body, 'remove', previousClass  if previousClass
      KDView.setElementClass body, 'add', name
      previousClass = name

  loadView:(mainView)->

    mainView.mainTabView.on "MainTabPaneShown", (pane)=>
      @mainTabPaneChanged mainView, pane

  mainTabPaneChanged:(mainView, pane)->

    appManager      = KD.getSingleton 'appManager'
    app             = appManager.getFrontApp()
    {mainTabView}   = mainView
    {navController} = KD.singleton 'dock'

    # KD.singleton('display').emit "ContentDisplaysShouldBeHidden"
    # temp fix
    # until fixing the original issue w/ the dnd this should be kept here
    if pane
    then @setViewState pane.getOptions()
    else mainTabView.getActivePane().show()

    {title} = app?.getOption('navItem')

    if title
    then navController.selectItemByName title
    else navController.deselectAllItems()


  setViewState: do ->

    (options = {})->

      {behavior, name} = options
      {body}           = document
      html             = document.getElementsByTagName('html')[0]
      mainView         = @getView()
      {mainTabView}    = mainView
      o                = {name}

      KDView.setElementClass html, 'remove', 'app'
      switch behavior
        when 'hideTabs'
          o.hideTabs = yes
          o.type     = 'social'
        when 'application'
          o.hideTabs = no
          o.type     = 'develop'
          KDView.setElementClass html, 'add', 'app'
        else
          o.hideTabs = no
          o.type     = 'social'

      @emit "UILayoutNeedsToChange", o

      # if options.name is 'Activity'
      # if KD.introView

      KDView.setElementClass body, 'remove', 'intro'
      mainView.unsetClass 'home'
      KD.introView?.unsetClass 'in'
      KD.introView?.setClass 'out'

  #     group = KD.getSingleton('groupsController').getCurrentGroup()

  #     if group.slug is 'koding'
  #     then @decorateHome()
  #     else @clearHome()

  # decorateHome:->
  #   mainView = @getView()
  #   {logo, chatPanel, chatHandler} = mainView

  #   chatHandler.hide()
  #   chatPanel.hide()
  #   mainView.setClass 'home'
  #   logo.setClass 'large'
  #   KD.introView?.show()

  # clearHome:->
  #   mainView = @getView()
  #   {homeIntro, logo, chatPanel, chatHandler} = mainView

  #   KD.introView.hide()
  #   KD.utils.wait 300, ->
  #     chatHandler.show()
  #     chatPanel.show()
  #   mainView.unsetClass 'home'
  #   logo.unsetClass 'large'
  #   KD.introView?.hide()
