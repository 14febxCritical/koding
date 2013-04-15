class GroupsInvitationRequestsView extends GroupsRequestView

  controllerNames = ['pendingList','sentList','resolvedList']

  constructor:(options, data)->

    options.cssClass = "groups-invitation-request-view"

    super

    group = @getData()

    @timestamp = new Date 0

    @prepareSentList()
    @prepareRequestList()
    @prepareResolvedList()

    @currentState = new KDView cssClass: 'formline'

    @invitationTypeFilter =
      options.invitationTypeFilter ? ['basic approval','invitation']

    @statusFilter =
      options.statusFilter ? ['pending','sent','approved', 'declined']

    @inviteMember = new KDFormViewWithFields
      fields            :
        recipient       :
          label         : "Send to"
          type          : "text"
          name          : "recipient"
          placeholder   : "Enter an email address..."
          validate      :
            rules       :
              required  : yes
              email     : yes
            messages    :
              required  : "An email address is required!"
              email     : "That does not not seem to be a valid email address!"
      buttons           :
        'Send invite'   :
          loader        :
            color       : "#444444"
            diameter    : 12
          callback      : => @sendInviteToMember()

    @prepareBulkInvitations()
    @batchInvites = new KDFormViewWithFields
      cssClass          : 'invite-tools'
      buttons           :
        'Send invites'  :
          title         : 'Send invitation batch'
          callback      : =>
            @emit 'BatchInvitationsAreSent', +@batchInvites.getFormData().Count
      fields            :
        Count           :
          label         : "# of Invites"
          type          : "text"
          defaultValue  : 10
          placeholder   : "how many users do you want to invite?"
          validate      :
            rules       :
              regExp    : /\d+/i
            messages    :
              regExp    : "numbers only please"
        Status          :
          label         : "Server response"
          type          : "hidden"
          nextElement   :
            statusInfo  :
              itemClass : KDView
              partial   : '...'
              cssClass  : 'information-line'
    , group

    @refresh()

    @utils.defer =>
      @parent.on 'NewInvitationActionArrived', =>
        @refresh()

  getControllers:->
    (@["#{controllerName}Controller"] for controllerName in controllerNames)

  refresh:->

    @fetchSomeRequests @invitationTypeFilter, @statusFilter, (err, requests)=>
      if err then console.error err
      else

        groupedRequests = {}

        requests.reverse().forEach (request)->

          requestGroup =
            if request.status in ['approved','declined']
              groupedRequests.resolved ?= []
            else
              groupedRequests[request.status] ?= []

          requestGroup.push request

        {pending, sent, resolved} = groupedRequests

        # clear out any items that may be there already:
        @getControllers().forEach (controller)-> controller.removeAllItems()

        # populate the lists:
        @pendingListController.instantiateListItems pending     if pending?
        @sentListController.instantiateListItems sent           if sent?
        @resolvedListController.instantiateListItems resolved   if resolved?

    return this

  prepareSentList:->
    @sentListController = new InvitationRequestListController
      viewOptions       :
        cssClass        : 'request-list'
      itemClass         : GroupsInvitationListItemView
      showDefaultItem   : yes
      defaultItem       :
        options         :
          cssClass      : 'default-item'
          partial       : 'No invitations sent'

    @forwardEvent @sentListController, 'ShowMoreRequested', 'Sent'

    @sentRequestList = @sentListController.getView()
    return @sentRequestList

  prepareRequestList:->
    @pendingListController = new InvitationRequestListController
      viewOptions       :
        cssClass        : 'request-list'
      itemClass         : GroupsInvitationRequestListItemView
      showDefaultItem   : yes
      defaultItem       :
        options         :
          cssClass      : 'default-item'
          partial       : 'No invitations pending'

    @pendingList = @pendingListController.getView()

    listView = @pendingListController.getListView()

    @forwardEvent listView, 'RequestIsApproved'
    @forwardEvent listView, 'RequestIsDeclined'

    @forwardEvent @pendingListController, 'ShowMoreRequested', 'Pending'

    return @pendingList

  prepareResolvedList:->
    @resolvedListController = new InvitationRequestListController
      showDefaultItem   : yes
      defaultItem       :
        options         :
          cssClass      : 'default-item'
          partial       : 'No requests resolved'

    @forwardEvent @resolvedListController, 'ShowMoreRequested', 'Resolved'

    @resolvedList = @resolvedListController.getView()
    return @resolvedList

  sendInviteToMember:->
    email = @inviteMember.getFormData().recipient
    KD.remote.api.JGroup.one {_id:@getData()._id}, (err, group)=>
      if err then console.warn err
      else
        group.inviteMember email, (err)=>
          @inviteMember.buttons['Send invite'].hideLoader()
          if err then console.warn err
          else
            @refresh()
            console.log 'done'

  pistachio:->
    """
    <section class="formline status-quo">
      <h2>Status quo</h2>
      {{> @currentState}}
    </section>
    <div class="formline">
      <section class="formline email">
        <h2>Invite member by email</h2>
        {{> @inviteMember}}
      </section>
      <section class="formline batch">
        <h2>Invite members by batch</h2>
        {{> @batchInvites}}
      </section>
    </div>
    <div class="formline">
      <section class="formline pending">
        <h2>Pending requests</h2>
        {{> @pendingList}}
      </section>
      <section class="formline sent">
        <h2>Sent invitations</h2>
        {{> @sentRequestList}}
      </section>
    </div>
    <div class="formline">
      <section class="formline resolved">
        <h2>Resolved requests</h2>
        {{> @resolvedList}}
      </section>
    </div>
    """