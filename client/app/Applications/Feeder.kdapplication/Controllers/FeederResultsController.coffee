class FeederResultsController extends KDViewController
  constructor:(options = {}, data)->
    options.view                or= new FeederTabView hideHandleCloseIcons : yes
    options.paneClass           or= FeederTabPaneView
    options.itemClass           or= KDListItemView
    options.listControllerClass or= KDListViewController

    super options,data

    @panes = {}
    @listControllers = {}

    for name, filter of options.filters
      @createTab name,filter

  loadView:(mainView)->
    mainView.hideHandleContainer()
    mainView.showPaneByIndex 0
    # baad
    setTimeout ->
      mainView._windowDidResize()
    ,500

  openTab:(filter, callback)->
    tabView = @getView()
    pane = tabView.getPaneByName filter.name
    tabView.showPane pane
    callback? @listControllers[filter.name]

  createTab:(name, filter, callback)->
    {paneClass,itemClass,listControllerClass,listCssClass} = @getOptions()
    tabView = @getView()

    @listControllers[name] = listController = new listControllerClass
      lazyLoadThreshold   : .75
      startWithLazyLoader : yes
      noItemFoundText     : filter.noItemFoundText or null
      viewOptions         :
        cssClass          : listCssClass
        itemClass         : itemClass
        type              : name

    forwardItemWasAdded = @emit.bind this, 'ItemWasAdded'

    listController.getListView().on 'ItemWasAdded', forwardItemWasAdded

    listController.on 'LazyLoadThresholdReached', =>
      @emit "LazyLoadThresholdReached"



    tabView.addPane @panes[name] = new paneClass
      name : name

    @panes[name].addSubView @panes[name].listHeader = header = new CommonListHeader
      title : filter.optional_title or filter.title

    @panes[name].addSubView @panes[name].listWrapper = listController.getView()

    listController.scrollView?.on 'scroll', (event) =>
      if event.delegateTarget.scrollTop > 0
        header.setClass "scrolling-up-outset"
      else
        header.unsetClass "scrolling-up-outset"

    callback? listController
