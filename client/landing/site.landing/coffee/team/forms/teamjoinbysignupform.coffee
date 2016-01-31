kd = require 'kd.js'
JView           = require './../../core/jview'
TeamJoinTabForm = require './../forms/teamjointabform'
LoginInputView  = require './../../login/logininputview'


module.exports = class TeamJoinBySignupForm extends TeamJoinTabForm

  constructor: ->

    super

    teamData = kd.utils.getTeamData()

    @email = new LoginInputView
      inputOptions      :
        name            : 'email'
        placeholder     : 'your email address'
        defaultValue    : teamData.invitation?.email
        validate        :
          rules         : { email: yes }
          messages      : { email: 'Please type a valid email address.' }
          events        :
            regExp      : 'keyup'

    @email.inputReceivedKeyup()  if teamData.invitation?.email

    @username = new LoginInputView
      inputOptions       :
        placeholder      : 'pick a username'
        name             : 'username'
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
            regExp       : 'keyup'

    @passwordStrength = ps = new kd.CustomHTMLView
      tagName  : 'figure'
      cssClass : 'PasswordStrength'
      partial  : '<span></span>'

    # make this a reusable component - SY
    oldPass   = null
    @password = new LoginInputView
      inputOptions    :
        type          : 'password'
        name          : 'password'
        placeholder   : 'set a password'
        validate      :
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

          kd.utils.checkPasswordStrength pass, (err, report) ->
            oldPass = pass

            return if pass isnt report.password  # to avoid late responded ajax calls

            ps.unsetClass strength.join ' '
            ps.setClass strength[report.score]

    @button     = @getButton 'Sign up & join'
    @buttonLink = @getButtonLink "Have an account? <a href='#'>Log in now</a>", (event) =>
      kd.utils.stopDOMEvent event
      return  unless event.target.tagName is 'A'
      @emit 'FormNeedsToBeChanged', yes, yes

    @on 'FormValidationFailed', @button.bound 'hideLoader'
    @on 'FormSubmitFailed',     @button.bound 'hideLoader'


  submit: (formData) ->

    teamData = kd.utils.getTeamData()
    teamData.signup.alreadyMember = no

    super formData


  pistachio: ->

    """
    {{> @email}}
    {{> @username}}
    {{> @password}}
    {{> @passwordStrength}}
    <div class='TeamsModal-button-separator'></div>
    {{> @button}}
    {{> @buttonLink}}
    """
