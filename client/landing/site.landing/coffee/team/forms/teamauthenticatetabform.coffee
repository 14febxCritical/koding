kd    = require 'kd.js'
utils = require './../../core/utils'
JView = require './../../core/jview'

module.exports = class TeamAuthenticateTabForm extends kd.FormView

  JView.mixin @prototype

  constructor:(options = {}, data)->

    options.cssClass = 'clearfix'

    super options, data

    @label = new kd.LabelView
      title : 'Occasionally Koding can share relevant announcements with me.'
      for   : 'newsletter'

    @checkbox = new kd.InputView
      defaultValue : on
      type         : 'checkbox'
      name         : 'newsletter'
      label        : @label

    team     = utils.getTeamData()
    username = email.split('@').first  if email = team.signup?.email

    @username = new kd.InputView
      placeholder  : 'username'
      name         : 'username'
      defaultValue : username  if username

    @passwordStrength = ps = new kd.CustomHTMLView
      tagName  : 'figure'
      cssClass : 'PasswordStrength'
      partial  : '<span></span>'

    # make this a reusable component - SY
    oldPass   = null
    @password = new kd.InputView
      type          : 'password'
      name          : 'password'
      placeholder   : '*********'
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

        utils.checkPasswordStrength pass, (err, report) ->
          oldPass = pass

          return if pass isnt report.password  #to avoid late responded ajax calls

          ps.unsetClass strength.join ' '
          ps.setClass strength[report.score]



    @button = new kd.ButtonView
      title      : 'Continue to environment setup'
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
