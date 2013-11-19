class ResendEmailConfirmationLinkInlineForm extends LoginViewInlineForm

  constructor:->

    super
    @usernameOrEmail = new LoginInputView
      inputOptions    :
        name          : "username-or-email"
        placeholder   : "Enter username or email"
        testPath      : "recover-password-input"
        validate      :
          container   : this
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your username or email."

    @button = new KDButtonView
      title       : "RESEND CONFIRMATION EMAIL"
      style       : "koding-orange"
      type        : 'submit'
      loader      :
        color     : "#ffffff"
        diameter  : 21

  pistachio:->

    """
    <div>{{> @usernameOrEmail}}</div>
    <div>{{> @button}}</div>
    """
