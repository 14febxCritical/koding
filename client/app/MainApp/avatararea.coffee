class AvatarAreaIconLink extends KDCustomHTMLView
  constructor:(options,data)->
    options = $.extend
      tagName     : "a"
      partial     : "<span class='count'><cite></cite><span class='arrow-wrap'><span class='arrow'></span></span></span><span class='icon'></span>"
      attributes  :
        href      : "#"
    ,options
    super options,data
    @count = 0
  
  updateCount:(newCount = 0)->
    
    @$('.count cite').text newCount
    @count = newCount

    if newCount is 0
      @$('.count').removeClass "in"
    else
      @$('.count').addClass "in"
  
  click:->
    popup = @getDelegate()
    popup.show()
  

class AvatarAreaIconMenu extends KDView
  constructor:->
    super
    @setClass "actions"
  
  viewAppended:->
    mainView = @getSingleton 'mainView'
    sidebar  = @getDelegate()
    @setClass "invisible" unless KD.isLoggedIn()
  
    mainView.addSubView @avatarStatusUpdatePopup = new AvatarPopupShareStatus
      cssClass : "status-update"
      delegate : sidebar

    mainView.addSubView @avatarNotificationsPopup = new AvatarPopupNotifications
      cssClass : "notifications"
      delegate : sidebar

    mainView.addSubView @avatarMessagesPopup = new AvatarPopupMessages
      cssClass : "messages"
      delegate : sidebar
  
    @addSubView @statusUpdateIcon = new AvatarAreaIconLink 
      cssClass   : 'status-update'
      attributes :
        title    : 'Status Update'
      delegate   : @avatarStatusUpdatePopup

    @addSubView @notificationsIcon = new AvatarAreaIconLink 
      cssClass   : 'notifications'
      attributes :
        title    : 'Notifications'
      delegate   : @avatarNotificationsPopup

    @addSubView @messagesIcon = new AvatarAreaIconLink 
      cssClass   : 'messages'
      attributes :
        title    : 'Messages'
      delegate   : @avatarMessagesPopup
  
    @attachListeners()
  
  attachListeners:->

    # @getSingleton('notificationController').on "NotificationHasArrived", (notification)=>
    #   @notificationsIcon.updateCount @notificationsIcon.count + 1
    
    @getSingleton('notificationController').on 'NotificationHasArrived', ({event})=>
      @notificationsIcon.updateCount @notificationsIcon.count + 1 if event is 'ActivityIsAdded'
    
    @avatarNotificationsPopup.listController.on 'NotificationCountDidChange', (count)=>
      @utils.killWait @avatarNotificationsPopup.loaderTimeout
      @notificationsIcon.updateCount count

    @avatarMessagesPopup.listController.on 'MessageCountDidChange', (count)=>
      @utils.killWait @avatarMessagesPopup.loaderTimeout
      @messagesIcon.updateCount count
    
    @avatarNotificationsPopup.on 'ReceivedClickElsewhere', =>
      @notificationsIcon.updateCount 0
  
  accountChanged:(account)->
    if KD.isLoggedIn()
      @unsetClass "invisible"
      notificationsPopup = @avatarNotificationsPopup
      messagesPopup      = @avatarMessagesPopup
      messagesPopup.listController.removeAllItems()
      notificationsPopup.listController.removeAllItems()
      
      #do not remove the timeout it should give dom sometime before putting an extra load
      notificationsPopup.loaderTimeout = @utils.wait 5000, =>
        notificationsPopup.listController.fetchNotificationTeasers (teasers)=>
          notificationsPopup.listController.instantiateListItems teasers

      messagesPopup.loaderTimeout = @utils.wait 5000, =>
        messagesPopup.listController.fetchMessages()

    else
      @setClass "invisible"

    @avatarMessagesPopup.accountChanged()

class AvatarPopup extends KDView
  constructor:->
    super
    @sidebar = @getDelegate()

    @sidebar.on "NavigationPanelWillCollapse", => @hide()

    @on 'ReceivedClickElsewhere', => @hide()

    @_windowController = @getSingleton('windowController')
    @listenWindowResize()

  show:->
    @utils.killWait @loaderTimeout
    @_windowDidResize()
    @_windowController.addLayer @
    @getSingleton('mainController').emit "AvatarPopupIsActive"
    @setClass "active"
    @

  hide:->
    @_windowController.removeLayer @
    @getSingleton('mainController').emit "AvatarPopupIsInactive"
    @unsetClass "active"
    @

  viewAppended:->
    @setClass "avatararea-popup"
    @addSubView @avatarPopupTab = new KDView cssClass : 'tab', partial : '<span class="avatararea-popup-close"></span>'
    @setPopupListener()
    @addSubView @avatarPopupContent = new KDView cssClass : 'content'

  setPopupListener:->
    @listenTo
      KDEventTypes        : 'click'
      listenedToInstance  : @avatarPopupTab
      callback        :(pubInst, event)->
        @hide()
  
  _windowDidResize:=>
    if @listController
      {scrollView}    = @listController
      windowHeight    = $(window).height()
      avatarTopOffset = @$().offset().top
      @listController.scrollView.$().css maxHeight : windowHeight - avatarTopOffset - 50
    


# avatar popup box Status Update Form
class AvatarPopupShareStatus extends AvatarPopup
  show:->
    super()
    
    if (visitor = KD.getSingleton('mainController').getVisitor())
      {profile} = visitor.currentDelegate
      if @statusField.getOptions().placeholder is ""
        @statusField.setPlaceHolder "What's new, #{Encoder.htmlDecode profile.firstName}?"
    
  viewAppended:->
    super()

    @avatarPopupContent.addSubView @statusField = new KDHitEnterInputView
      type          : "textarea"
      validate      :
        rules       :
          required  : yes
      callback      : (status)=> @updateStatus status


  updateStatus:(status)->

    bongo.api.JStatusUpdate.create body : status, (err,reply)=>
      unless err
        appManager.tell 'Activity', 'ownActivityArrived', reply
        new KDNotificationView
          type     : 'growl'
          cssClass : 'mini'
          title    : 'Message posted!'
          duration : 2000
        @statusField.setValue ""
        @statusField.setPlaceHolder reply.body
        @hide()
        
      else
        new KDNotificationView type : "mini", title : "There was an error, try again later!"
        @hide()
        
# avatar popup box Notifications
class AvatarPopupNotifications extends AvatarPopup
  activitesArrived:-> console.log arguments
  
  viewAppended:->
    super()

    @_popupList = new PopupList 
      subItemClass : PopupNotificationListItem
      # lastToFirst   : yes

    @listController = new MessagesListController 
      view         : @_popupList
      maxItems     : 5

    @listController.registerListener
      KDEventTypes  : "AvatarPopupShouldBeHidden"
      listener      : @
      callback      : => @hide()
    
    @avatarPopupContent.addSubView @listController.getView()

    @avatarPopupContent.addSubView redirectLink = new KDView
      height   : "auto"
      cssClass : "sublink"
      partial  : "<a href='#'>View all of your activity notifications...</a>"
    
    @listenTo 
      KDEventTypes        : "click"
      listenedToInstance  : redirectLink
      callback            : ()=>
        appManager.openApplication('Inbox')
        appManager.tell 'Inbox', "goToNotifications"
        @hide()

  show:->
    super
    @listController.fetchNotificationTeasers (notifications)=>
      @listController.removeAllItems()
      @listController.instantiateListItems notifications

    KD.whoami().glanceActivities ->
    
class AvatarPopupMessages extends AvatarPopup
  
  viewAppended:->
    super()
    
    @_popupList = new PopupList
      subItemClass  : PopupMessageListItem
      # lastToFirst   : yes
    
    @listController = new MessagesListController 
      view         : @_popupList
      maxItems     : 5

    @getSingleton('notificationController').on "NewMessageArrived", => 
      @listController.fetchMessages()

    @listController.registerListener
      KDEventTypes  : "AvatarPopupShouldBeHidden"
      listener      : @
      callback      : => @hide()

    @listController.registerListener
      KDEventTypes  : "AvatarPopupShouldBeHidden"
      listener      : @
      callback      : => @hide()
    
    @avatarPopupContent.addSubView @listController.getView()
    
    @avatarPopupContent.addSubView redirectLink = new KDView
      height   : "auto"
      cssClass : "sublink"
      partial  : "<a href='#'>See all messages...</a>"
    
    @listenTo
      KDEventTypes        : "click"
      listenedToInstance  : redirectLink
      callback            : ->
        appManager.openApplication('Inbox')
        appManager.tell 'Inbox', "goToMessages"
        @hide()
  
  accountChanged:->
    @listController.removeAllItems()
  
  show:->
    super
    @listController.fetchMessages()
    KD.whoami().glanceMessages ->

class PopupList extends KDListView

  constructor:(options = {}, data)->
    
    options.tagName     or= "ul"
    options.cssClass    or= "avatararea-popup-list"
    # options.lastToFirst or= no
  
    super options,data
  
class PopupNotificationListItem extends NotificationListItem
  
  constructor:(options = {}, data)->
    
    options.tagName        or= "li"
    options.linkGroupClass or= LinkGroup
    options.avatarClass    or= AvatarView

    super options, data

  pistachio:->
    """
      <span class='icon'></span>
      <span class='avatar'>{{> @avatar}}</span>
      <div class='right-overflow'>
        <p>{{> @participants}} {{@getActionPhrase #(dummy)}} {{@getActivityPlot #(dummy)}}</p>
        <footer>
          <time>{{$.timeago @getLatestTimeStamp #(dummy)}}</time>
        </footer>
      </div>
    """
  
  click:(event)->

    popupList = @getDelegate()
    popupList.propagateEvent KDEventType : 'AvatarPopupShouldBeHidden'
    super


class PopupMessageListItem extends KDListItemView
  constructor:(options,data)->
    options = $.extend
      tagName : "li"
    ,options

    super options,data
    
    @initializeReadState()
    
    group = data.participants.map (participant)->
      constructorName : participant.sourceName
      id              : participant.sourceId
    
    @participants = new ProfileTextGroup {group}
    @avatar       = new AvatarStaticView {
      size    : {width: 40, height: 40}
      origin  : group[0]
    }
  
  initializeReadState:->
    if @getData().getFlagValue('read')
      @unsetClass 'unread'
    else
      @setClass 'unread'
  
  viewAppended:->
    @setTemplate @pistachio()
    @template.update()

  teaser:(text)->
    __utils.shortenText(text, minLength: 40, maxLength: 70) or ''

  click:(event)->
    appManager.openApplication 'Inbox'
    appManager.tell "Inbox", "goToMessages", @
    popupList = @getDelegate()
    popupList.propagateEvent KDEventType : 'AvatarPopupShouldBeHidden'

  pistachio:->
    """
    <span class='avatar'>{{> @avatar}}</span>
    <div class='right-overflow'>
      <a href='#'>{{#(subject) or '(No title)'}}</a><br/>
      {{@teaser #(body)}}
      <footer>
        <time>{{> @participants}} {{$.timeago #(meta.createdAt)}}</time>
      </footer>
    </div>
    """
