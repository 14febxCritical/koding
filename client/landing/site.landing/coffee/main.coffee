console.time 'Koding.com loaded'

require './core/utils'
require './core/KD.extend.coffee'

# register appclasses
require './login/AppController'
require './team/AppController'
require './teams/AppController'

# bootstrap app
kookies        = require 'kookies'
MainController = require './core/maincontrollerloggedout'

do ->

  registerRoutes = ->

    require './core/routes.coffee'
    require './login/routes.coffee'
    require './teams/routes.coffee'
    require './team/routes.coffee'

  setGroup = (err, group) ->
    registerRoutes()
    require './pricing/routes.coffee'
    require './legal/routes.coffee'
    require './features/routes.coffee'
    KD.config.group = group  if group
    # BIG BANG
    new MainController group


  KD.config             or= {}
  KD.config.environment   = if location.hostname is 'koding.com' then 'production' else 'development'
  KD.config.groupName     = groupName = KD.utils.getGroupNameFromLocation()
  KD.config.recaptcha     = window._runtimeOptions.recaptcha
  KD.config.google        = window._runtimeOptions.google

  if groupName is 'koding'
  then setGroup()
  else KD.utils.checkIfGroupExists groupName, setGroup
