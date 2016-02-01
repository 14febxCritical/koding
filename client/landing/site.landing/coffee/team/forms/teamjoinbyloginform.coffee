JView           = require './../../core/jview'
TeamJoinTabForm = require './../forms/teamjointabform'
LoginInputView  = require './../../login/logininputview'


module.exports = class TeamJoinByLoginForm extends TeamJoinTabForm

  constructor: ->

    super

    @username = new LoginInputView
      inputOptions    :
        placeholder   : 'your username'
        name          : 'username'
        validate      :
          rules       : { required: yes }
          messages    : { required: 'Please enter a username.' }


    teamData                = utils.getTeamData()
    if teamData.profile
      { firstName, nickname } = teamData.profile
      name     = "#{firstName or '@'+nickname}"
      partial  = "Are you #{name}? <a href='#'>Login here!</a>"
      callback = (event) =>
        kd.utils.stopDOMEvent event
        return  unless event.target.tagName is 'A'
        @emit 'FormNeedsToBeChanged', yes, no
    else
      name     = "#{firstName or '@'+nickname}"
      partial  = "Don't have an account? <a href='#'>Sign up!</a>"
      callback = (event) =>
        kd.utils.stopDOMEvent event
        return  unless event.target.tagName is 'A'
        @emit 'FormNeedsToBeChanged', no, no

    @password   = @getPassword()
    @tfcode     = @getTFCode()
    @button     = @getButton "Join #{kd.config.groupName}!"
    @buttonLink = @getButtonLink partial, callback

    @on 'FormSubmitFailed', @button.bound 'hideLoader'


  submit: (formData) ->

    teamData = utils.getTeamData()
    teamData.signup.alreadyMember = yes

    super formData


  pistachio: ->

    """
    {{> @username}}
    {{> @password}}
    {{> @tfcode}}
    <p class='dim'>
      <a href='//#{utils.getMainDomain()}/Recover' target='_self'>Forgot your password?</a>
    </p>
    <div class='TeamsModal-button-separator'></div>
    {{> @buttonLink}}
    {{> @button}}
    """
