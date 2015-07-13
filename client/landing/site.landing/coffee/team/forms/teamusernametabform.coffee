JView = require './../../core/jview'

module.exports = class TeamUsernameTabForm extends KDFormView

  JView.mixin @prototype

  constructor:(options = {}, data)->

    options.cssClass = 'clearfix'

    super options, data

    @label = new KDLabelView
      title : 'Occasionally Koding can share relevant announcements with me.'
      for   : 'newsletter'

    @checkbox = new KDInputView
      defaultValue : on
      type         : 'checkbox'
      name         : 'newsletter'
      label        : @label

    team        = KD.utils.getTeamData()
    emailPrefix = email.split('@').first  if email = team.signup?.email
    username    = emailPrefix  if emailPrefix?.length > 3

    @username = new KDInputView
      placeholder      : 'username'
      name             : 'username'
      defaultValue     : username  if username
      validate         :
        rules          :
          required     : yes
          rangeLength  : [4, 25]
          regExp       : /^[a-z\d]+([-][a-z\d]+)*$/i
        messages       :
          required     : 'Please enter a username.'
          regExp       : 'For username only lowercase letters and numbers are allowed!'
          rangeLength  : 'Username should be between 4 and 25 characters!'
        events         :
          required     : 'blur'
          rangeLength  : 'blur'
          regExp       : 'keyup'

    @passwordStrength = ps = new KDCustomHTMLView
      tagName  : 'figure'
      cssClass : 'PasswordStrength'
      partial  : '<span></span>'

    # make this a reusable component - SY
    oldPass   = null
    @password = new KDInputView
      type          : 'password'
      name          : 'password'
      placeholder   : 'password'
      validate      :
        event       : 'blur'
        container   : this
        rules       :
          required  : yes
          minLength : 8
        messages    :
          required  : 'Please enter a password.'
          minLength : 'Passwords should be at least 8 characters.'
      keyup         : (event) ->
        pass     = @getValue()
        strength = ['bad', 'weak', 'moderate', 'good', 'excellent']

        return  if pass is oldPass
        if pass is ''
          ps.unsetClass strength.join ' '
          oldPass = null
          return

        KD.utils.checkPasswordStrength pass, (err, report) ->
          oldPass = pass

          return if pass isnt report.password  # to avoid late responded ajax calls

          ps.unsetClass strength.join ' '
          ps.setClass strength[report.score]

    @button = new KDButtonView
      title      : 'Continue to environmental setup'
      style      : 'TeamsModal-button TeamsModal-button--green'
      attributes : testpath : 'register-button'
      type       : 'submit'


  pistachio: ->

    """
    <div class='login-input-view'><span>Username</span>{{> @username}}</div>
    <div class='login-input-view'><span>Password</span>{{> @password}}{{> @passwordStrength}}</div>
    <p class='dim'>Your username is how you will appear to other people on your team. Pick something others will recognize.</p>
    <div class='login-input-view tr'>{{> @checkbox}}{{> @label}}</div>
    {{> @button}}
    """