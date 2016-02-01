kd                          = require 'kd'
globals                     = require 'globals'
KDTabPaneView               = kd.TabPaneView
KDCustomHTMLView            = kd.CustomHTMLView
StackCatalogMainTabPaneView = require './stackcatalogmaintabpaneview'


module.exports = class StackCatalogModalView extends kd.ModalView


  constructor: (options = {}, data) ->

    options.useRouter ?= yes

    super options, data

    @addSubView @nav     = new kd.TabHandleContainer
      cssClass           : 'AppModal-nav'

    @addSubView @tabs    = new StackCatalogMainTabPaneView
      tabHandleContainer : @nav
      useRouter          : @getOption 'useRouter'
    , data

    @nav.unsetClass 'kdtabhandlecontainer'

    @setListeners()

    @overlay.once 'click', @bound 'handleOverlayClick'


  _windowDidResize: (e) ->

    height = if window.innerHeight < 600 then 100 else 90
    @setHeight height, '%'
    @setPositions()


  setListeners: ->

    @listenWindowResize()

    @tabs.on 'PaneAdded', (pane) ->
      { tabHandle } = pane
      tabHandle.setClass 'AppModal-navItem'
      tabHandle.unsetClass 'kdtabhandle'


  viewAppended: ->

    super

    kd.singletons.mainController.ready @bound 'createTabs'


  createTabs: ->

    group        = @getData()
    items        = []
    { tabData }  = @getOptions()

    for own sectionKey, section of tabData

      for item in section.items
        items.push item

        if item.subTabs
          for subTab in item.subTabs
            subTab.parentTabTitle = item.title
            items.push subTab

    @tabs.on 'PaneDidShow', (pane) ->
      return  if pane._isViewAdded

      slug       = pane.getOption 'slug'
      action     = pane.getOption 'action'
      identifier = pane.getOption 'identifier'
      targetItem = viewClass: KDCustomHTMLView

      for item in items
        if item.action is action
          targetItem = item
          break
        else if item.slug is slug
          targetItem = item
          break

      { viewClass } = targetItem

      pane._isViewAdded = yes
      pane.setMainView new viewClass
        cssClass : slug or action
        delegate : this
        action   : action
      , group

    items.forEach (item, i) =>

      { slug, title, action } = item
      name           = title or slug or action
      hiddenHandle   = if action then yes
      parentTabTitle = item.parentTabTitle or null

      pane = new KDTabPaneView { name, slug, action, hiddenHandle, title, parentTabTitle }
      @tabs.addPane pane, i is 0

    @emit 'ready'


  handleOverlayClick: ->

    stacksPane = @tabs.getPaneByName 'Stacks'

    return @destroy()  unless stacksPane

    { mainView }    = stacksPane
    { editorView }  = mainView?.defineStackView?.stackTemplateView

    unless editorView?.getAce().isContentChanged()
      @destroy()
