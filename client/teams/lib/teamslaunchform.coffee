kd    = require 'kd'
JView = require 'app/jview'

module.exports = class TeamsLaunchForm extends LoginViewInlineForm

  constructor: ->

    super

    @email = new LoginInputViewWithLoader
      inputOptions   :
        name         : 'email'
        placeholder  : 'Email address'
        validate     :
          rules      :
            email    : yes
          messages   :
            email    : 'Please type a valid email address.'

    @button = new kd.ButtonView
      title       : 'Sign up for early access'
      style       : 'solid medium green'
      attributes  : testpath : 'signup-company-button'
      type        : 'submit'


  pistachio:->
    """
    <section class='clearfix'>
      <div class='fl email'>{{> @email}}</div>
      <div class='fl submit'>{{> @button}}</div>
    </section>
    """

