class CommonInnerNavigation extends KDView

  constructor:(options = {}, data)->

    options.cssClass = KD.utils.curryCssClass "common-inner-nav", options.cssClass
    super options, data

  setListController:(options,data,isSorter = no)->

    controller = new CommonInnerNavigationListController options, data
    controller.getListView().on "NavItemReceivedClick", (data)=>
      @emit "NavItemReceivedClick", data

    @sortController = controller if isSorter

    return controller

  selectSortItem:(sortType)->
    return unless @sortController
    itemToBeSelected = null
    for item in @sortController.itemsOrdered
      if item.getData().type is sortType
        itemToBeSelected = item

    if itemToBeSelected
      @sortController.selectItem itemToBeSelected

class CommonInnerNavigationListController extends KDListViewController
  constructor:(options={},data)->
    options.viewOptions or= itemClass : options.itemClass or CommonInnerNavigationListItem
    options.view or= mainView = new CommonInnerNavigationList options.viewOptions
    super options,data

    listView = @getListView()

    listView.on 'ItemWasAdded', (view)=>
      view.on 'click', (event)=>
        unless view.getData().disabledForBeta
          @selectItem view
          @emit 'NavItemReceivedClick', view.getData()
          listView.emit 'NavItemReceivedClick', view.getData()

  loadView:(mainView)->
    list = @getListView()
    mainView.setClass "list"
    mainView.addSubView new KDHeaderView size : 'small', title : @getData().title, cssClass : "list-group-title"
    mainView.addSubView list
    @instantiateListItems(@getData().items or [])

  selectItemByName:(name)->
    item = null
    for navItem in @itemsOrdered when navItem.getData()?.title is name
      @selectItem item = navItem
      break
    return item

class CommonInnerNavigationList extends KDListView
  constructor : (options = {},data)->
    options.tagName or= "ul"
    super options,data

class CommonInnerNavigationListItem extends KDListItemView
  constructor : (options = {},data)->
    options.tagName or= "li"
    options.partial or= "<a href='#'>#{data.title}</a>"
    if data.disabledForBeta
      options = $.extend
        tooltip     :
          title     : "<p class='login-tip'>Coming Soon</p>"
          placement : "right"
          offset    :
            top     : 0
            left    : 3
      ,options
    super options,data
    @setClass data.type

  partial:()-> ""
