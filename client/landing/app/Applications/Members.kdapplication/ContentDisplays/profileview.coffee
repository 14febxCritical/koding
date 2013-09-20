class ProfileView extends JView
  constructor: (options = {}, data) ->
    super options, data

    @memberData = @getData()

    if KD.checkFlag 'exempt', @memberData
      if not KD.checkFlag 'super-admin'
        return KD.getSingleton('router').handleRoute "/Activity"

    @editButton = new KDCustomHTMLView
    if KD.isMine @memberData
      @editButton   = new KDButtonView
        testPath    : "profile-edit-button"
        cssClass    : "edit"
        style       : "clean-gray"
        title       : "Edit your profile"
        callback    : @bound 'onEdit'

    @saveButton     = new KDButtonView
      testPath      : "profile-save-button"
      cssClass      : "save hidden"
      style         : "cupid-green"
      title         : "Save"
      callback      : @bound 'onSave'

    @cancelButton   = new KDButtonView
      cssClass      : "cancel hidden"
      style         : "clean-red"
      title         : "Cancel"
      callback      : @bound 'onCancel'

    @firstName      = new KDContentEditableView
      testPath      : "profile-first-name"
      pistachio     : "{{#(profile.firstName) or ''}}"
      cssClass      : "firstName"
      placeholder   : "First name"
      delegate      : this
      validate      :
        rules       :
          required  : yes
          maxLength : 25
        messages    :
          required  : "First name is required"
      , @memberData

    @lastName       = new KDContentEditableView
      testPath      : "profile-last-name"
      pistachio     : "{{#(profile.lastName) or ''}}"
      cssClass      : "lastName"
      placeholder   : "Last name"
      delegate      : this
      validate      :
        rules       :
          maxLength : 25
      , @memberData

    @memberData.locationTags or= []

    @location     = new KDContentEditableView
      testPath    : "profile-location"
      pistachio   : "{{#(locationTags)}}"
      cssClass    : "location"
      placeholder : "Earth"
      default     : "Earth"
      delegate    : this
      , @memberData

    @bio            = new KDContentEditableView
      testPath      : "profile-bio"
      pistachio     : "{{ @utils.applyTextExpansions #(profile.about), yes}}"
      cssClass      : "bio"
      placeholder   : if KD.isMine @memberData then @bioPlaceholder else ""
      textExpansion : yes
      delegate      : this
      click         : (event) => KD.utils.showMoreClickHandler event
    , @memberData

    @firstName.on "NextTabStop", => @lastName.focus()
    @firstName.on "PreviousTabStop", => @bio.focus()
    @lastName.on "NextTabStop", => @location.focus()
    @lastName.on "PreviousTabStop", => @firstName.focus()
    @location.on "NextTabStop", => @bio.focus()
    @location.on "PreviousTabStop", => @lastName.focus()
    @bio.on "NextTabStop", => @firstName.focus()
    @bio.on "PreviousTabStop", => @lastName.focus()

    for input in [@firstName, @lastName, @location, @bio]
      input.on "click", => if not @editingMode and KD.isMine @memberData then @setEditingMode on

    if KD.isMine @memberData or @memberData.skillTags.length > 0
      @skillTagView = new SkillTagFormView {}, @memberData
    else
      @skillTagView = new KDCustomHTMLView

    @skillTagView.on "AutoCompleteNeedsTagData", (event) =>
      {callback, inputValue, blacklist} = event
      @fetchAutoCompleteDataForTags inputValue, blacklist, callback

    newAvatar      = ''
    avatarOptions  =
      size         :
        width      : 90
        height     : 90
      click        : =>
        pos        =
          top      : @avatar.getBounds().y - 8
          left     : @avatar.getBounds().x - 8

        modalOptions =
          width    : 400
          fx       : yes
          overlay  : yes
          draggable: yes
          position : pos

        if KD.isMine @memberData

          isVideoSupported = KDWebcamView.getUserMediaVendor()
          isDNDSupported   = do ->
            tester = document.createElement('div')
            "draggable" of tester or\
            ("ondragstart" of tester and "ondrop" of tester)

          modalOptions.buttons =
            gravatar:
              title   : "Use Gravatar"
              cssClass: "modal-clean-gray #{if @memberData.profile.avatar is '' then 'hidden' else ''}"
              callback: @bound "avatarSetGravatar"

            upload:
              title   : "Upload Image"
              cssClass: "modal-clean-gray #{unless isDNDSupported then 'hidden' else ''}"
              callback: @bound "avatarUploadImage"

            webcam:
              title   : "Take Photo"
              cssClass: "modal-clean-gray #{unless isVideoSupported then 'hidden' else ''}"
              callback: @bound "avatarCapturePhoto"

        @modal = new KDModalView modalOptions
        @modal.addSubView @bigAvatar = new AvatarStaticView
          size     :
            width  : 400
            height : 400
        , @memberData

    if KD.isMine @memberData
      avatarOptions.tooltip =
        title       : "<p class='centertext'>click to edit</p>"
        placement   : "below"
        arrow       :
          placement : "bottom"
          margin    : 300

    @avatar = new AvatarStaticView avatarOptions, @memberData

    userDomain = @memberData.profile.nickname + "." + KD.config.userSitesDomain
    @userHomeLink = new KDCustomHTMLView
      tagName     : "a"
      cssClass    : "user-home-link"
      attributes  :
        href      : "http://#{userDomain}"
        target    : "_blank"
      pistachio   : userDomain
      click       : (event) =>
        KD.utils.stopDOMEvent event unless @memberData.onlineStatus is "online"

    if KD.whoami().getId() is @memberData.getId()
      @followButton = new KDCustomHTMLView
    else
      @followButton = new MemberFollowToggleButton
        style : "kdwhitebtn profilefollowbtn"
      , @memberData

    for route in ['followers', 'following', 'likes']
      @[route] = @getActionLink route, @memberData

    @sendMessageLink = new KDCustomHTMLView
    unless KD.isMine @memberData
      @sendMessageLink = new MemberMailLink {}, @memberData

    if @sendMessageLink instanceof MemberMailLink
      @sendMessageLink.on "AutoCompleteNeedsMemberData", (pubInst,event) =>
        {callback, inputValue, blacklist} = event
        @fetchAutoCompleteForToField inputValue, blacklist, callback

      @sendMessageLink?.on 'MessageShouldBeSent', ({formOutput, callback}) =>
        @prepareMessage formOutput, callback

    if KD.checkFlag 'super-admin' and not KD.isMine @memberData
      @trollSwitch   = new KDCustomHTMLView
        tagName      : "a"
        partial      : if KD.checkFlag 'exempt', @memberData then 'Unmark Troll' else 'Mark as Troll'
        cssClass     : "troll-switch"
        click        : =>
          if KD.checkFlag 'exempt', @memberData
            KD.getSingleton('mainController').unmarkUserAsTroll @memberData
          else
            KD.getSingleton('mainController').markUserAsTroll @memberData
    else
      @trollSwitch = new KDCustomHTMLView

  uploadAvatar: (newAvatar, callback)->
    loader = new KDNotificationView
      overlay : yes
      title   : "Your avatar is being uploaded, please wait..."
      loader  :
        color : "#ffffff"
      duration: 30000
    FSHelper.s3.upload "avatar.png", newAvatar, (err, url)=>
      resized = KD.utils.proxifyUrl url,
        crop: true, width: 400, height: 400
      cssUrlPattern = "url(#{resized})"
      @bigAvatar.setAvatar cssUrlPattern
      @avatar.setAvatar cssUrlPattern
      @avatar.$().css backgroundSize: "100%"
      @memberData.modify "profile.avatar": [url, +new Date()].join("?"), (err)=>
        loader.destroy()
        callback? err
        @bigAvatar.show()
        unless err
          new KDNotificationView
            title: "Your avatar updated successfully!"
            type : "mini"

  avatarSetGravatar: ->
    modal = new KDModalView
      title   : "Are you sure?"
      content : """
      <div class="modalformline">
        <p>
          <strong>This will remove your current avatar!</strong>
        </p>
        <p>
          Are you sure you want to remove your picture and use your Gravatar?
        </p>
      </div>
      """
      buttons:
        "Yes, use Gravatar":
          cssClass: "modal-clean-green"
          callback: =>
            @memberData.modify "profile.avatar": "", (err)=>
              return log err if err
              modal.destroy()
              @modal.buttons.gravatar.hide()
        "Cancel":
          cssClass: "modal-cancel"
          callback: -> modal.destroy()

  avatarUploadImage: ->
    @bigAvatar.hide()
    @modal.addSubView uploader = new DNDUploader
      title       : "Drop your avatar here!"
      uploadToVM  : no
      size: height: 380

    uploader.showCancel()

    uploader.on "cancel", =>
      uploader.destroy()
      @bigAvatar.show()
      @modal.buttons.upload.enable()

    uploader.on "dropFile", ({origin, content})=>
      if origin is "external"
        newAvatar = btoa content
        @uploadAvatar newAvatar, ->
          uploader.emit "cancel"

    @modal.buttons.upload.disable()

  avatarCapturePhoto: ->
    newAvatar = ''
    @bigAvatar.hide()
    @modal.addSubView capture = new KDWebcamView
      countdown: 3
      snapTitle: "Take Avatar Picture"
      size:
        width : 400
        height: 400
    capture.on "snap", (data)-> [_, newAvatar] = data.split ','
    capture.on "save", =>
      @uploadAvatar newAvatar, =>
        @bigAvatar.show()
        capture.hide()

  setEditingMode: (state) ->
    @editingMode = state
    @emit "EditingModeToggled", state

    if state
      @editButton.hide()
      @saveButton.show()
      @cancelButton.show()
    else
      @editButton.show()
      @saveButton.hide()
      @cancelButton.hide()

  onEdit: ->
    @setEditingMode on
    @firstName.focus()

  onSave: ->
    for input in [@firstName, @lastName]
      unless input.validate() then return

    @setEditingMode off

    @memberData.modify
      "profile.firstName" : @firstName.getValue()
      "profile.lastName"  : @lastName.getValue()
      "profile.about"     : @bio.getValue()
      "locationTags"      : [@location.getValue() || "Earth"]
    , (err) =>
      if err
        state = "error"
        message = "There was an error updating your profile"
      else
        state = "success"
        message = "Your profile is updated"

      new KDNotificationView
        title    : message
        type     : "mini"
        cssClass : state
        duration : 2500

      @utils.defer =>
        @memberData.emit "update"

  onCancel: =>
    @setEditingMode off
    @memberData.emit "update"

  getActionLink: (route) ->
    count    = @memberData.counts[route] or 0
    nickname = @memberData.profile.nickname
    path     = route[0].toUpperCase() + route[1..-1]

    new KDView
      tagName     : 'a'
      attributes  :
        href      : "/#"
      pistachio   : "<cite/><span class=\"data\">#{count}</span> <span>#{path}</span>"
      click       : (event) =>
        event.preventDefault()
        unless @memberData.counts[route] is 0
          KD.getSingleton('router').handleRoute "/#{nickname}/#{path}", {state: @memberData}
    , @memberData

  fetchAutoCompleteForToField: (inputValue, blacklist, callback) ->
    KD.remote.api.JAccount.byRelevance inputValue,{blacklist},(err,accounts) ->
      callback accounts

  fetchAutoCompleteDataForTags:(inputValue, blacklist, callback) ->
    KD.remote.api.JTag.byRelevanceForSkills inputValue, {blacklist}, (err, tags) ->
      unless err
        callback? tags
      else
        log "there was an error fetching topics #{err.message}"

  # FIXME: this should be taken to inbox app controller using KD.getSingleton("appManager").tell
  prepareMessage: (formOutput, callback) ->
    {body, subject, recipients} = formOutput
    to = recipients.join ' '

    @sendMessage {to, body, subject}, (err, message) ->
      new KDNotificationView
        title     : if err then "Failure!" else "Success!"
        duration  : 1000
      message.mark 'read'
      callback? err, message

  sendMessage: (messageDetails, callback) ->
    if KD.isGuest()
      return new KDNotificationView
        title: "Sending private message for guests not allowed"

    KD.remote.api.JPrivateMessage.create messageDetails, callback

  putNick: (nick) -> "@#{nick}"

  putPresence: (state) ->
    """
      <div class="presence #{state or 'offline'}">
        #{state or 'offline'}
      </div>
    """

  updateUserHomeLink: ->
    return  unless @userHomeLink

    if @memberData.onlineStatus is "online"
      @userHomeLink.unsetClass "offline"
      @userHomeLink.tooltip?.destroy()
    else
      @userHomeLink.setClass "offline"

      @userHomeLink.setTooltip
        title     : "#{@memberData.profile.nickname}'s VM is offline"
        placement : "right"

  render: ->
    @updateUserHomeLink()
    super

  pistachio: ->
    account      = @getData()
    amountOfDays = Math.floor (new Date - new Date(account.meta.createdAt)) / (24*60*60*1000)
    onlineStatus = if account.onlineStatus then 'online' else 'offline'
    """
    <div class="profileleft">
      <span>{{> @avatar}}</span>
      {{> @followButton}}
      {cite{ @putNick #(profile.nickname)}}
      {div{ @putPresence #(onlineStatus)}}
    </div>

    {{> @trollSwitch}}

    <section>
      <div class="profileinfo">
        {{> @editButton}} {{> @saveButton}} {{> @cancelButton}}
        <h3 class="profilename">{{> @firstName}}{{> @lastName}}</h3>
        <h4 class="profilelocation">{{> @location}}</h4>
        <h5>
          {{> @userHomeLink}}
          <cite>member for #{if amountOfDays < 2 then 'a' else amountOfDays} day#{if amountOfDays > 1 then 's' else ''}.</cite>
        </h5>
        <div class="profilestats">
          <div class="fers">{{> @followers}}</div>
          <div class="fing">{{> @following}}</div>
          <div class="liks">{{> @likes}}</div>
          <div class='contact'>{{> @sendMessageLink}}</div>
        </div>
        <div class="profilebio">{{> @bio }}</div>
        <div class="personal-skilltags">{{> @skillTagView}}</div>
      </div>
    </section>
    """

  bioPlaceholder: "You haven't entered anything in your bio yet. Why not add something now?"
