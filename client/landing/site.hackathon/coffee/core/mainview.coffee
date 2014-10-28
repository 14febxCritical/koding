TopNavigation  = require './topnavigation'
CustomLinkView = require './customlinkview'
MainTabView    = require './maintabview'

module.exports = class MainView extends KDView

  constructor: (options = {}, data)->

    options.domId    = 'kdmaincontainer'
    options.cssClass = if KD.isLoggedInOnLoad then 'with-sidebar' else ''

    super options, data

    @notifications = []


  viewAppended: ->

    {mainController} = KD.singletons

    @createHeader()
    @createPanelWrapper()
    @createMainTabView()

    @emit 'ready'

  createHeader:->

    @addSubView @header = new KDView
      tagName    : 'header'
      domId      : 'main-header'
      attributes :
        testpath : 'main-header'

    @header.addSubView @logo = new KDCustomHTMLView
      tagName    : 'a'
      domId      : 'koding-logo'
      partial    : '<cite></cite>'
      attributes :
        href     : 'https://koding.com'
        target   : '_blank'

    @header.addSubView @header.nav = new TopNavigation

  createPanelWrapper:->

    @addSubView @panelWrapper = new KDView
      tagName  : 'section'
      domId    : 'main-panel-wrapper'

    @panelWrapper.addSubView new KDCustomHTMLView
      tagName  : 'cite'
      domId    : 'sidebar-toggle'
      click    : => @toggleClass 'collapsed'


  createMainTabView:->

    @mainTabView = new MainTabView
      domId               : 'main-tab-view'
      listenToFinder      : yes
      delegate            : this
      slidingPanes        : no
      hideHandleContainer : yes


    @mainTabView.on 'PaneDidShow', (pane) => @emit 'MainTabPaneShown', pane

    @mainTabView.on "AllPanesClosed", -> KD.singletons.router.clear()

    @panelWrapper.addSubView @mainTabView
