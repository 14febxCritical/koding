class ContentDisplayControllerApps extends KDViewController
  constructor:(options = {}, data)->

    options.view or= mainView = new KDView cssClass : 'apps content-display'
    data = data.first  if Array.isArray data

    super options, data

  loadView:(mainView)->

    app = @getData()

    mainView.addSubView subHeader = new KDCustomHTMLView tagName : "h2", cssClass : 'sub-header'
    subHeader.addSubView backLink = new KDCustomHTMLView
      tagName     : "a"
      partial     : "<span>&laquo;</span> Back"
      attributes  :
        href      : "#"
      click       : (event)->
        event.stopPropagation()
        event.preventDefault()
        contentDisplayController.emit "ContentDisplayWantsToBeHidden", mainView

    contentDisplayController = @getSingleton "contentDisplayController"

    # mainView.addSubView wrapperView = new AppViewMainPanel {}, app

    mainView.addSubView appView = new AppView
      cssClass : "profilearea clearfix"
      delegate : mainView
    , app

    mainView.addSubView appView = new AppDetailsView
      cssClass : "info-wrapper"
      delegate : mainView
    , app
