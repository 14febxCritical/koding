class AccountNavigationLink extends KDTreeItemView
  constructor:(options,data)->
    super options,data
    @name = data.title

  click:(event)->
    @getDelegate().propagateEvent (KDEventType : "AccountNavLinkTitleClick"), @
    # @getDelegate().handleEvent (type : "AccountNavLinkTitleClick", orgEvent : event, pageName : @getData().title, navItem : @)
    
  partial:(data)->
    $ "<div class='navigation-item account clearfix'>
        <a class='title' href='#'><span class='main-nav-icon #{__utils.slugify data.title}'></span>#{data.title}</a>
      </div>"


class AccountListWrapper extends KDView

  listClasses =
    personal                   :
      username                 : AccountEditUsername
      security                 : AccountEditSecurity
      linkedAccountsController : AccountLinkedAccountsListController
      linkedAccounts           : AccountLinkedAccountsList
    billing                    :
      historyController        : AccountPaymentHistoryListController
      history                  : AccountPaymentHistoryList
      methodsController        : AccountPaymentMethodsListController
      methods                  : AccountPaymentMethodsList
      subscriptionsController  : AccountSubscriptionsListController
      subscriptions            : AccountSubscriptionsList
    develop                    :
      databasesController      : AccountDatabaseListController
      databases                : AccountDatabaseList
      editorsController        : AccountEditorListController
      editors                  : AccountEditorList
      mountsController         : AccountMountListController
      mounts                   : AccountMountList
      reposController          : AccountRepoListController
      repos                    : AccountRepoList
      keysController           : AccountSshKeyListController
      keys                     : AccountSshKeyList

  viewAppended:->

    data = @getData()

    @addSubView @header = new KDHeaderView type : "medium",title : data.item.listHeader
    
    @list = new listClasses[data.section.id][data.item.listType]
      cssClass : "#{data.section.id}-#{data.item.listType}"

    listControllerClass = listClasses[data.section.id]["#{data.item.listType}Controller"] or KDListViewController
    listController = new listControllerClass
      view : @list
    
    @addSubView listController.getView()
    
    @list.on "passwordDidChange",()-> log "password"

class AccountsSwappable extends KDView
  constructor:(options,data)->
    options = $.extend
      views : []          # an Array of two KDView instances
    ,options
    super
    @setClass "swappable"
    @addSubView(@view1 = @options.views[0]).hide()
    @addSubView @view2 = @options.views[1]

  swapViews:()=>
    if @view1.$().is(":visible")
      @view1.hide()
      @view2.show()
    else
      @view1.show()
      @view2.hide()