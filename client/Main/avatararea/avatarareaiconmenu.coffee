class AvatarAreaIconMenu extends JView

  constructor:->

    super

    @setClass "account-menu"

    @helpIcon    = new AvatarAreaIconLink
      cssClass   : "help acc-dropdown-icon"
      attributes :
        title    : 'Help'

    @helpIcon.click = (event)=>
      KD.singletons.helpController.showHelp this
      KD.utils.stopDOMEvent event
      @animation?.destroy()

    @notificationsPopup = new AvatarPopupNotifications
      cssClass : "notifications"

    @notificationsIcon = new AvatarAreaIconLink
      cssClass   : 'notifications acc-dropdown-icon'
      attributes :
        title    : 'Notifications'
      delegate   : @notificationsPopup

    {mainController, troubleshoot} = KD.singletons
    troubleshoot.on "userIdle", =>
      idleModal = new KDModalView
        title          : "You were away from Koding for a while."
        content        : "Your dev VMs might have been turned off. Please check \
                          system status before you progress."
        overlay        : yes
        buttons        :
          Troubleshoot :
            style      : "modal-clean-green"
            callback   : ->
              idleModal.destroy()
              new TroubleshootModal
          Close        :
            style      : "modal-cancel"
            callback   : -> idleModal.destroy()


    mainController.ready =>
      storage = KD.singletons.localStorageController.storage('HelpController')
      unless storage.getValue 'shown'
        # KD.utils.wait 5000, =>
        #   KD.singletons.helpController.showHelp @helpIcon
        @helpIcon.addSubView @animation = new KDCustomHTMLView
          tagName    : "span"
          cssClass   : "intro-marker in help"

  pistachio:->
    """
    {{> @helpIcon}}
    {{> @notificationsIcon}}
    """

  viewAppended:->

    super

    mainView = KD.getSingleton 'mainView'
    mainView.addSubView @notificationsPopup

    @attachListeners()
    KD.getSingleton('mainController').on "AccountChanged", =>
      @attachListeners()


  attachListeners:->
    KD.getSingleton('notificationController').on 'NotificationHasArrived', ({event})=>
      # No need the following
      # @notificationsIcon.updateCount @notificationsIcon.count + 1 if event is 'ActivityIsAdded'
      if event is 'ActivityIsAdded' or 'BucketIsUpdated'
        @notificationsPopup.listController.fetchNotificationTeasers (notifications)=>
          @notificationsPopup.noNotification.hide()
          @notificationsPopup.listController.removeAllItems()
          @notificationsPopup.listController.instantiateListItems filterNotifications notifications

    @notificationsPopup.listController.on 'NotificationCountDidChange', (count)=>
      @utils.killWait @notificationsPopup.loaderTimeout
      if count > 0
      then @notificationsPopup.noNotification.hide()
      else @notificationsPopup.noNotification.show()
      @notificationsIcon.updateCount count

  accountChanged:(account)->

    {notificationsPopup} = this

    notificationsPopup.listController.removeAllItems()

    if KD.isLoggedIn()
      # Fetch Notifications
      notificationsPopup.listController.fetchNotificationTeasers (teasers)=>
        notificationsPopup.listController.instantiateListItems filterNotifications teasers

  filterNotifications=(notifications)->
    activityNameMap = [
      "JNewStatusUpdate"
      "JAccount"
      "JPrivateMessage"
      "JComment"
      "JReview"
      "JGroup"
    ]
    notifications.filter (notification) ->
      snapshot = JSON.parse Encoder.htmlDecode notification.snapshot
      snapshot.anchor.constructorName in activityNameMap