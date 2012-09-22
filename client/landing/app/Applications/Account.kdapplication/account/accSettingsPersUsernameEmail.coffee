class AccountEditUsername extends KDView

  viewAppended:->
    KD.remote.api.JUser.fetchUser (err,user)=>
      @putContents KD.whoami(), user

  putContents:(account, user)->

    # #
    # ADDING EMAIL FORM
    # #
    @addSubView @emailForm = emailForm = new KDFormView
      callback     : (formData)->
        bongo.api.JUser.changeEmail
          email : formData.email
        , (err, result)=>
          log err
          if err and err.name isnt 'PINExistsError'
            new KDNotificationView
              title    : err.message
              duration : 2000
          else
            new VerifyPINModal 'Update E-Mail', (pin)=>
              bongo.api.JUser.changeEmail
                email : formData.email
                pin   : pin
              , (err)->
                new KDNotificationView
                  title    : if err then err.message else "E-mail changed!"
                  duration : 2000
                # FIXME update the view in some way

          emailSwappable.swapViews()

    emailForm.addSubView emailLabel = new KDLabelView
      title        : "Your email"
      cssClass     : "main-label"

    emailInputs = new KDView cssClass : "hiddenval clearfix"
    emailInputs.addSubView emailInput = new KDInputView
      label        : emailLabel
      defaultValue : user.email
      placeholder  : "you@yourdomain.com..."
      name         : "email"
    emailInputs.addSubView inputActions = new KDView cssClass : "actions-wrapper"
    inputActions.addSubView emailSave = new KDButtonView
      title        : "Save"
      type         : 'submit'
    inputActions.addSubView emailCancel = new KDCustomHTMLView
      tagName      : "a"
      partial      : "cancel"
      cssClass     : "cancel-link"

    # EMAIL STATIC PART
    nonEmailInputs = new KDView cssClass : "initialval clearfix"

    nonEmailInputs.addSubView emailSpan = new KDCustomHTMLView
      tagName      : "span"
      partial      : user.email
      cssClass     : "static-text status-#{user.status}"
    nonEmailInputs.addSubView emailEdit = new KDCustomHTMLView
      tagName      : "a"
      partial      : "Edit"
      cssClass     : "action-link"

    # SET EMAIL SWAPPABLE
    emailForm.addSubView emailSwappable = new AccountsSwappable
      views    : [emailInputs,nonEmailInputs]
      cssClass : "clearfix"

    @listenTo KDEventTypes : "click", listenedToInstance : emailCancel, callback : emailSwappable.swapViews
    @listenTo KDEventTypes : "click", listenedToInstance : emailEdit,   callback : emailSwappable.swapViews

    # #
    # ADDING USERNAME FORM
    # #
    @addSubView usernameForm = usernameForm = new KDFormView
      callback     : (formData)->
        new KDNotificationView
          type  : "mini"
          title : "Currently disabled!"
    usernameForm.addSubView usernameLabel = new KDLabelView
      title        : "Your username"
      cssClass     : "main-label"

    usernameInputs = new KDView cssClass : "hiddenval clearfix"
    usernameInputs.addSubView usernameInput = new KDInputView
      label        : usernameLabel
      defaultValue : account.profile.nickname
      placeholder  : "username..."
      name         : "username"
    usernameInputs.addSubView inputActions = new KDView cssClass : "actions-wrapper"
    inputActions.addSubView usernameSave = new KDButtonView
      title        : "Save"
      type         : "submit"
    inputActions.addSubView usernameCancel = new KDCustomHTMLView
      tagName      : "a"
      partial      : "cancel"
      cssClass     : "cancel-link"

    # USERNAME STATIC PART
    usernameNonInputs = usernameNonInputs = new KDView cssClass : "initialval clearfix"
    usernameNonInputs.addSubView usernameSpan = new KDCustomHTMLView
      tagName      : "span"
      partial      : account.profile.nickname
      cssClass     : "static-text"
    usernameNonInputs.addSubView usernameEdit = new KDCustomHTMLView
      tagName      : "a"
      partial      : "Edit"
      cssClass     : "action-link"

    # SET USERNAME SWAPPABLE
    usernameForm.addSubView usernameSwappable = new AccountsSwappable
      views    : [usernameInputs,usernameNonInputs]
      cssClass : "clearfix"

    @listenTo KDEventTypes : "click", listenedToInstance : usernameCancel, callback : usernameSwappable.swapViews
    @listenTo KDEventTypes : "click", listenedToInstance : usernameEdit,   callback : usernameSwappable.swapViews

    @addSubView @emailOptOutView = new KDFormView
    @emailOptOutView.addSubView new KDLabelView
      title        : "Email notifications"
      cssClass     : "main-label"

    emailFrequency = user.getAt('emailFrequency.global')

    @emailOptOutView.addSubView new KDOnOffSwitch
      cssClass      : 'dark'
      defaultValue  : if emailFrequency is 'never' then off else on
      callback      : (state)->
        account.setEmailPreferences global: state, ->
          new KDNotificationView
            duration : 2000
            title    : if state then 'You will get email notifications.' \
                                else 'You will no longer get email notifications.'