class ActivityUpdateWidget extends KDView

  constructor:(options = {}, data)->

    options.domId    = "activity-update-widget"
    options.cssClass = "activity-update-widget-wrapper"

    super options, data

    @windowController = KD.getSingleton('windowController')
    @listenWindowResize()

  setMainSections:->
    @updatePartial ''
    @addSubView widgetWrapper = new KDView
      cssClass : 'widget-holder clearfix'

    widgetWrapper.addSubView @widgetButton = new WidgetButton @widgetOptions()

    widgetWrapper.addSubView @mainInputTabs = new KDTabView
      height   : "auto"
      cssClass : "update-widget-tabs"

    @mainInputTabs.hideHandleContainer()

    @on "WidgetTabChanged", (tabName)=>
      @windowController.addLayer @mainInputTabs

    @mainInputTabs.on "ResetWidgets", (isHardReset) => @resetWidgets isHardReset

    @mainInputTabs.on 'ReceivedClickElsewhere', (event)=>
      unless $(event.target).closest('.activity-status-context').length > 0

        # if there is a modal present, it MIGHT be used to enter
        # large amounts of text   --arvid
        unless $(event.target).closest('.kdmodal').length > 0
          @resetWidgets()

  resetWidgets: (isHardReset) ->
    @windowController.removeLayer @mainInputTabs
    @unsetClass "edit-mode"
    @changeTab "update", "Status Update"
    @mainInputTabs.emit "MainInputTabsReset", isHardReset

    @_windowDidResize()

  addWidgetPane:(options)->

    {paneName,mainContent} = options

    @mainInputTabs.addPane main = new KDTabPaneView
      name : paneName
    main.addSubView mainContent if mainContent?
    return main

  changeTab:(tabName, title)->

    @showPane tabName
    @widgetButton.decorateButton tabName, title
    @_windowDidResize()
    @emit "WidgetTabChanged", tabName

  showPane:(paneName)->

    @mainInputTabs.showPane @mainInputTabs.getPaneByName paneName

  viewAppended:->
    @setMainSections()
    super

  _windowDidResize:->

    width = @getWidth()
    @$('.form-headline, form.status-update-input').width width - 185

  widgetOptions:->

    title             : "Status Update"
    style             : "activity-status-context"
    icon              : yes
    iconClass         : "update"
    delegate          : @

    menu              :
      "Status Update" :
        type          : "update"
        callback      : (treeItem, event)=> @changeTab "update", treeItem.getData().title
      "Blog Post":
        type          : "blogpost"
        callback      : (treeItem, event)=> @changeTab "blogpost", treeItem.getData().title
      "Code Snip"     :
        type          : "codesnip"
        callback      : (treeItem, event)=> @changeTab "codesnip", treeItem.getData().title
      "Discussion"    :
        type          : "discussion"
        disabled      : no
        callback      : (treeItem, event)=> @changeTab "discussion", treeItem.getData().title
      "Tutorial"      :
        type          : "tutorial"
        disabled      : no
        callback      : (treeItem, event)=> @changeTab "tutorial", treeItem.getData().title
    callback          : =>




class ActivityWidgetFormView extends KDFormView

  constructor :(options, data)->

    super

    @labelAddTags = new KDLabelView
      title           : "Add Tags:"

    @selectedItemWrapper = new KDCustomHTMLView
      tagName         : "div"
      cssClass        : "tags-selected-item-wrapper clearfix"

    @tagController = new TagAutoCompleteController
      name                : "meta.tags"
      type                : "tags"
      itemClass           : TagAutoCompleteItemView
      selectedItemClass   : TagAutoCompletedItemView
      outputWrapper       : @selectedItemWrapper
      selectedItemsLimit  : 5
      listWrapperCssClass : "tags"
      itemDataPath        : 'title'
      form                : @
      dataSource          : (args, callback)=>
        {inputValue} = args
        updateWidget = @getDelegate()
        blacklist = (data.getId() for data in @tagController.getSelectedItemData() when 'function' is typeof data.getId)
        KD.getSingleton("appManager").tell "Topics", "fetchTopics", {inputValue, blacklist}, callback

    @tagAutoComplete = @tagController.getView()
