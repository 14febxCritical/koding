class AvatarPopupGroupSwitcher extends AvatarPopup

  constructor:->
    @notLoggedInMessage = 'Login required to switch groups'
    super

  viewAppended:->

    super

    @pending = 0
    @notPopulated = yes
    @notPopulatedPending = yes

    @_popupList = new PopupList
      itemClass  : PopupGroupListItem

    @_popupListPending = new PopupList
      itemClass  : PopupGroupListItemPending

    @_popupListPending.on 'PendingCountDecreased', @bound 'decreasePendingCount'
    @_popupListPending.on 'UpdateGroupList',       @bound 'populateGroups'
    # does not work
    # KD.whoami().on        'NewPendingInvitation',  @bound 'populatePendingGroups'

    @listControllerPending = new KDListViewController
      lazyLoaderOptions   :
        partial           : ''
        spinnerOptions    :
          loaderOptions   :
            color         : '#6BB197'
          size            :
            width         : 32
      view                : @_popupListPending

    @listController = new KDListViewController
      lazyLoaderOptions   :
        partial           : ''
        spinnerOptions    :
          loaderOptions   :
            color         : '#6BB197'
          size            :
            width         : 32
      view                : @_popupList

    @listController.on "AvatarPopupShouldBeHidden", @bound 'hide'

    @avatarPopupContent.addSubView @invitesHeader = new KDView
      height   : "auto"
      cssClass : "sublink top hidden"
      partial  : "You have pending group invitations:"

    @avatarPopupContent.addSubView @listControllerPending.getView()

    @avatarPopupContent.addSubView new KDCustomHTMLView
      tagName    : 'span'
      cssClass   : 'icon help'
      tooltip    :
        title    : "Here you'll find the groups that you are a member of, clicking one of them will take you to a new browser tab."

    @avatarPopupContent.addSubView @listController.getView()

    groupsController = KD.getSingleton("groupsController")
    groupsController.once 'GroupChanged', () =>
      group =  groupsController.getCurrentGroup()
      if group?.slug isnt "koding"
        backToKodingView.updatePartial "<a class='right' target='_blank' href='/Activity'>Back to Koding</a>"

    @avatarPopupContent.addSubView new KDCustomHTMLView
      tagName    : 'a'
      attributes : href : '/Account'
      cssClass   : 'bottom separator'
      partial    : 'Account settings'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        KD.getSingleton('router').handleRoute '/Account'
        @hide()


    @avatarPopupContent.addSubView new KDCustomHTMLView
      tagName    : 'a'
      attributes : href : '/Environments'
      cssClass   : 'bottom'
      partial    : 'Environments'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        KD.getSingleton('router').handleRoute '/Environments'
        @hide()


    @avatarPopupContent.addSubView dashboard = new KDCustomHTMLView
      tagName    : 'a'
      attributes : href : '/Dashboard'
      cssClass   : 'bottom hidden'
      partial    : 'Dashboard'

    # FIXME:
    KD.utils.wait 2000, =>
      group = KD.getSingleton("groupsController").getCurrentGroup()
      group?.canEditGroup (err, success)=>
        if success
          dashboard.show()
          dashboard.on 'click', (event)=>
            KD.utils.stopDOMEvent event
            KD.getSingleton('router').handleRoute '/Dashboard'
            @hide()

    @avatarPopupContent.addSubView new KDCustomHTMLView
      tagName    : 'a'
      attributes : href : '#'
      cssClass   : 'bottom'
      partial    : 'Go back to old Koding'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        modal = new KDModalView
          title   : "Go back to old Koding"
          cssClass: "go-back-survey"
          content : """
            Please take a short survey about <a href="http://bit.ly/1jsjlna">New Koding.</a><br><br>
            """
          buttons :
            "Switch":
              cssClass: "modal-clean-gray"
              callback: ->
                KD.mixpanel "Switched to old Koding"
                KD.utils.goBackToOldKoding()
                modal.destroy()
            "Cancel":
              cssClass: "modal-cancel"
              callback: ->
                modal.destroy()
        @hide()

    @avatarPopupContent.addSubView new KDCustomHTMLView
      tagName    : 'a'
      attributes : href : '/Logout'
      cssClass   : 'bottom'
      partial    : 'Logout'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        KD.getSingleton('router').handleRoute '/Logout'
        @hide()

  populatePendingGroups:->
    @listControllerPending.removeAllItems()
    @listControllerPending.hideLazyLoader()

    return  unless KD.isLoggedIn()

    KD.whoami().fetchGroupsWithPendingInvitations (err, groups)=>
      if err then warn err
      else if groups?
        @pending = 0
        for group in groups when group
          @listControllerPending.addItem {group, roles:[], admin:no}
          @pending++
        @updatePendingCount()
        @notPopulatedPending = no


  populateGroups:->
    return  unless KD.isLoggedIn() or @isLoading

    @listController.removeAllItems()

    @isLoading = yes

    KD.whoami().fetchGroups null, (err, groups)=>
      if err then warn err
      else if groups?

        stack = []
        groups.forEach (group)->
          stack.push (cb)->
            group.group.fetchMyRoles (err, roles)->
              group.admin = unless err then 'admin' in roles else no
              cb err, group

        async.parallel stack, (err, results)=>
          @isLoading = no

          unless err
            results.sort (a, b)->
              return if a.admin is b.admin
              then a.group.slug > b.group.slug
              else not a.admin and b.admin

            index = null
            results.forEach (item, i)->
              index = i  if item.group.slug is 'koding'

            results.splice index, 1  if index?

            @listController.hideLazyLoader()
            @listController.instantiateListItems results

  decreasePendingCount:->
    @pending--
    @updatePendingCount()

  updatePendingCount:->
    @listControllerPending.emit 'PendingGroupsCountDidChange', @pending

  show:->
    super
    # in case user opens popup earlier than timed out initial population
    @populateGroups() if @notPopulated
    @populatePendingGroups() if @notPopulatedPending

class PopupGroupListItem extends KDListItemView

  constructor:(options = {}, data)->
    options.tagName or= "li"
    super

    {group:{title, avatar, slug}, roles, admin} = @getData()

    roleClasses = roles.map((role)-> "role-#{role}").join ' '
    @setClass "role #{roleClasses}"

    @switchLink = new CustomLinkView
      title       : title
      href        : "/#{if slug is KD.defaultSlug then '' else slug+'/'}Activity"
      target      : slug
      icon        :
        cssClass  : 'new-page'
        placement : 'right'
        tooltip   :
          title   : "Opens in a new browser window."
          delayIn : 300

    @adminLink = new CustomLinkView
      title       : ''
      href        : "/#{if slug is KD.defaultSlug then '' else slug+'/'}Dashboard"
      target      : slug
      cssClass    : 'fr'
      iconOnly    : yes
      icon        :
        cssClass  : 'dashboard-page'
        placement : 'right'
        tooltip   :
          title   : "Opens admin dashboard in new browser window."
          delayIn : 300
    unless admin
      @adminLink.hide()

  viewAppended: JView::viewAppended

  pistachio: ->
    """
    <div class='right-overflow'>
      {{> @switchLink}}
      {{> @adminLink}}
    </div>
    """

class PopupGroupListItemPending extends PopupGroupListItem

  constructor:(options = {}, data)->
    super

    {group} = @getData()
    @setClass 'role pending'

    @acceptButton = new KDButtonView
      style       : 'clean-gray'
      title       : 'Accept Invitation'
      icon        : yes
      iconOnly    : yes
      iconClass   : 'accept'
      tooltip     :
        title     : 'Accept Invitation'
      callback    : =>
        KD.whoami().acceptInvitation group, (err)=>
          if err then warn err
          else
            @destroy()
            @parent.emit 'PendingCountDecreased'
            @parent.emit 'UpdateGroupList'

    @ignoreButton = new KDButtonView
      style       : 'clean-gray'
      title       : 'Ignore Invitation'
      icon        : yes
      iconOnly    : yes
      iconClass   : 'ignore'
      tooltip     :
        title     : 'Ignore Invitation'
      callback    : =>
        KD.whoami().ignoreInvitation group, (err)=>
          if err then warn err
          else
            new KDNotificationView
              title    : 'Ignored!'
              content  : 'If you change your mind, you can request access to the group anytime.'
              duration : 2000
            @destroy()
            @parent.emit 'PendingCountDecreased'

  viewAppended: JView::viewAppended

  pistachio: ->
    """
    <div class='right-overflow'>
      <div class="buttons">
        {{> @acceptButton}}
        {{> @ignoreButton}}
      </div>
      {{> @switchLink}}
    </div>
    """
