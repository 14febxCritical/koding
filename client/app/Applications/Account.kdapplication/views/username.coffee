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
        KD.remote.api.JUser.changeEmail
          email : formData.email
        , (err, result)=>
          log err
          if err and err.name isnt 'PINExistsError'
            new KDNotificationView
              title    : err.message
              duration : 2000
          else
            if err and err.name is 'PINExistsError'
              new KDNotificationView
                title    : err.message
                duration : 2000
            new VerifyPINModal 'Update E-Mail', (pin)=>
              KD.remote.api.JUser.changeEmail
                email : formData.email
                pin   : pin
              , (err)=>
                new KDNotificationView
                  title    : if err then err.message else "E-mail changed!"
                  duration : 2000
                @emit "EmailChangedSuccessfully", formData.email

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
      testPath     : "account-email-input"

    emailInputs.addSubView inputActions = new KDView cssClass : "actions-wrapper"
    inputActions.addSubView emailSave = new KDButtonView
      title        : "Save"
      type         : 'submit'
    inputActions.addSubView emailCancel = new KDCustomHTMLView
      tagName      : "a"
      partial      : "cancel"
      cssClass     : "cancel-link"
      click        : => emailSwappable.swapViews()

    # EMAIL STATIC PART
    nonEmailInputs = new KDView cssClass : "initialval clearfix"

    nonEmailInputs.addSubView emailSpan = new KDCustomHTMLView
      tagName      : "span"
      partial      : user.email
      cssClass     : "static-text status-#{user.status}"

    emailForm.on "EmailChangedSuccessfully", (email)->
      emailSpan.updatePartial email

    nonEmailInputs.addSubView emailEdit = new KDCustomHTMLView
      tagName      : "a"
      partial      : "Edit"
      cssClass     : "action-link"
      testPath     : "account-email-edit"
      click        : => emailSwappable.swapViews()

    verifyEmail = new KDView
    if user.status is "unconfirmed"
      verifyEmail = new KDCustomHTMLView
        tagName      : "a"
        partial      : "You didn't verify your email yet - Verify now"
        cssClass     : "action-link verify-email"
        testPath     : "account-email-edit"
        click        : =>
          KD.remote.api.JEmailConfirmation.resetToken KD.whoami().profile.nickname, (err)=>
            message = if err then err.message else "Email confirmation mail is sent"
            new KDNotificationView
              title    : message
              duration : 3500
            verifyEmail.hide()


    nonEmailInputs.addSubView verifyEmail

    # SET EMAIL SWAPPABLE
    emailForm.addSubView emailSwappable = new AccountsSwappable
      views    : [emailInputs,nonEmailInputs]
      cssClass : "clearfix"

    # #
    # ADDING USERNAME FORM
    # #
    @addSubView usernameForm = usernameForm = new KDFormView
      callback     : (formData)->
        # KD.whoami().changeUsername formData.username
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
      testPath     : "account-username-input"
    usernameInputs.addSubView inputActions = new KDView cssClass : "actions-wrapper"
    inputActions.addSubView usernameSave = new KDButtonView
      title        : "Save"
      type         : "submit"
    inputActions.addSubView usernameCancel = new KDCustomHTMLView
      tagName      : "a"
      partial      : "cancel"
      cssClass     : "cancel-link"
      click        : => usernameSwappable.swapViews()

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
      testPath     : "account-username-edit"
      click        : => usernameSwappable.swapViews()

    # SET USERNAME SWAPPABLE
    usernameForm.addSubView usernameSwappable = new AccountsSwappable
      views    : [usernameInputs,usernameNonInputs]
      cssClass : "clearfix"
