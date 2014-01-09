class DemosAppController extends AppController

  if location.hostname is 'localhost'
    KD.registerAppClass this,
      name         : "Demos"
      route        : "/Demos"
      behavior     : "application"

  constructor:(options = {}, data)->
    options.view    = new DemosMainView
    options.appInfo =
      name          : "Demos"

    super options, data
