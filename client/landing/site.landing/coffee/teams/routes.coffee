do ->

  handleRoute = ({params, query}) ->

    { router } = KD.singletons
    groupName  = KD.utils.getGroupNameFromLocation()

    # redirect to main.domain/Teams since it doesn't make sense to
    # advertise teams on a team domain - SY
    if groupName isnt 'koding'
      href = location.href
      href = href.replace "#{groupName}.", ''
      location.assign href
      return

    cb = (app) -> app.handleQuery query  if query

    KD.singletons.router.openSection 'Teams', null, null, cb


  handleInvitation = (routeInfo) ->

    { params, query } = routeInfo
    { token }         = params

    return KD.singletons.router.handleRoute '/'  unless token

    KD.utils.routeIfInvitationTokenIsValid token,
      success   : ({email}) ->
        KD.utils.storeNewTeamData 'invitation', { teamAccessCode: token, email }
        handleRoute { params, query }
      error     : ({responseText}) ->
        new KDNotificationView title : responseText
        KD.singletons.router.handleRoute '/'


  KD.registerRoutes 'Teams',

    '/Teams'       : -> KD.singletons.router.handleRoute '/'
    '/Teams/:token': handleInvitation