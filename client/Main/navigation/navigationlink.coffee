class NavigationLink extends KDListItemView

  constructor:(options = {}, data={})->

    href = if ep = KD.config.entryPoint then ep.slug + data.path else data.path

    data.type        or= ''
    options.tagName  or= 'a'
    options.type     or= 'main-nav'
    # options.draggable  =
    #   axis             : 'x'
    #   containment      : 'parent' #KD.getSingleton('DockController').getView()
    options.attributes = {href}
    options.cssClass   = KD.utils.curry @utils.slugify(data.title), options.cssClass

    super options, data

    @name = data.title

    @icon = new KDCustomHTMLView
      cssClass : 'fake-icon'
      partial  : "<span class='logo'>#{@name[0]}</span>"
    @icon.setCss 'backgroundColor', KD.utils.getColorFromString @name

    @icon.hide()  if @name in ['Activity', 'Topics', 'Terminal', \
                               'Editor', 'Apps', 'Teamwork', 'Finder']

    @on "DragStarted", @bound 'dragStarted'

    @on "DragInAction", @bound 'dragInAction'

    @on "DragFinished", @bound 'dragFinished'

  setState:(state = 'initial')->

    states = 'running failed loading'
    @unsetClass states
    if state in states.split ' ' then @setClass state

  click:(event)->
    KD.utils.stopDOMEvent event
    {appPath, title, path, type, topLevel} = @getData()

    # This check is for custom items which isn't connected to an app
    # or if the item is a separator
    return unless path

    mc = KD.getSingleton 'mainController'
    mc.emit "NavigationLinkTitleClick",
      pageName  : title
      appPath   : appPath or title
      path      : path
      topLevel  : topLevel
      navItem   : this

  viewAppended: JView::viewAppended

  pistachio:->
    """
      {{> @icon}}
      <span class='icon'></span>
      <cite>#{@name}</cite>
    """

  dragInAction: (x, y)->
    # log x, y

  dragStarted: (event, dragState)->

    @setClass 'no-anim'

  dragFinished: (event, dragState)->

    @unsetClass 'no-anim'