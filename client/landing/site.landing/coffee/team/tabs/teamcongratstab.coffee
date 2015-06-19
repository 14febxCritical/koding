JView              = require './../../core/jview'
MainHeaderView     = require './../../core/mainheaderview'

module.exports = class TeamCongratzTab extends KDTabPaneView

  JView.mixin @prototype

  constructor:(options = {}, data)->

    options.name = 'congrats'

    super options, data

    { mainController } = KD.singletons

    @header = new MainHeaderView
      cssClass : 'team'
      navItems : []

    teamData = KD.utils.getTeamData()
    { slug } = teamData.domain

    @button = new KDButtonView
      title      : "Sign in to #{slug}.koding.com"
      style      : 'TeamsModal-button TeamsModal-button--green'
      callback   : ->
  pistachio: ->

    """
    {{> @header }}
    <div class="TeamsModal TeamsModal--groupCreation">
      <figure class='congrats'></figure>
      <h4>Congratulations!</h4>
      <h5>Now please go ahead and login to your team page and setup your compute stacks and communication channels for your team members.</h5>
      <p class='dim'>Don't worry we'll show you how.</p>
      {{> @button}}
    </div>
    """