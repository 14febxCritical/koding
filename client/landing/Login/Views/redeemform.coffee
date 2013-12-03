class RedeemInlineForm extends LoginViewInlineForm

  constructor:(options={}, data)->
    super options, data

    @inviteCode = new LoginInputView
      inputOptions    :
        name          : "inviteCode"
        placeholder   : "Enter your invite code"
        validate      :
          container   : this
          rules       :
            required  : yes
          messages    :
            required  : "Please enter your invite code."

    @button = new KDButtonView
      title       : "Redeem"
      style       : "solid green"
      type        : 'submit'
      loader      :
        color     : "#ffffff"
        diameter  : 21

  pistachio:->
    """
    <div>{{> @inviteCode}}</div>
    <div>{{> @button}}</div>
    """
