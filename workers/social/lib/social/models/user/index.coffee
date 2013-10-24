jraphical = require 'jraphical'

Flaggable = require '../../traits/flaggable'

module.exports = class JUser extends jraphical.Module
  {secure}       = require 'bongo'
  {daisy, dash}  = require 'sinkrow'

  JAccount       = require '../account'
  JSession       = require '../session'
  JInvitation    = require '../invitation'
  JName          = require '../name'
  JGroup         = require '../group'
  JLog           = require '../log'
  JMail          = require '../email'

  createId       = require 'hat'

  {Relationship} = jraphical

  createKodingError =(err)->
    if 'string' is typeof err
      message: err
    else
      message: err.message

  @bannedUserList = ['abrt','amykhailov','apache','about','visa','shared-',
                     'cthorn','daemon','dbus','dyasar','ec2-user','http',
                     'games','ggoksel','gopher','haldaemon','halt','mail',
                     'nfsnobody','nginx','nobody','node','operator','https',
                     'root','rpcuser','saslauth','shutdown','sinanlocal',
                     'sshd','sync','tcpdump','uucp','vcsa','zabbix',
                     'search','blog','activity','guest','credits','about',
                     'kodingen','alias','backup','bin','bind','daemon',
                     'Debian-exim','dhcp','drweb','games','gnats','klog',
                     'kluser','libuuid','list','mhandlers-user','more',
                     'mysql','nagios','news','nobody','popuser','postgres',
                     'proxy','psaadm','psaftp','qmaild','qmaill','qmailp',
                     'qmailq','qmailr','qmails','sshd','statd','sw-cp-server',
                     'sync','syslog','tomcat','tomcat55','uucp','what',
                     'www-data','fuck','porn','p0rn','porno','fucking',
                     'fucker','admin','postfix','puppet','main','invite',
                     'administrator','members','register','activate','shared',
                     'groups','blogs','forums','topics','develop','terminal',
                     'term','twitter','facebook','google','framework', 'kite']

  @hashUnhashedPasswords =->
    @all {salt: $exists: no}, (err, users)->
      users.forEach (user)-> user.changePassword user.getAt('password')

  hashPassword =(value, salt)->
    require('crypto').createHash('sha1').update(salt+value).digest('hex')

  createSalt = require 'hat'

  @share()

  @trait __dirname, '../../traits/flaggable'

  @getFlagRole =-> 'owner'

  @set
    softDelete      : yes
    broadcastable   : no
    indexes         :
      username      : 'unique'
      email         : 'unique'
      'foreignAuth.github.foreignId'   : 1
      'foreignAuth.odesk.foreignId'    : 1
      'foreignAuth.facebook.foreignId' : 1

    sharedEvents    :
      static        : [
        { name : "RemovedFromCollection" }
      ]
      instance      : [
        { name : "RemovedFromCollection" }
      ]
    sharedMethods   :
      instance      : ['sendEmailConfirmation']
      static        : [
        'login','logout','usernameAvailable','emailAvailable',
        'changePassword','changeEmail','fetchUser','setDefaultHash','whoami',
        'isRegistrationEnabled','convert','setSSHKeys', 'getSSHKeys',
        'authenticateWithOauth','unregister'
      ]

    schema          :
      username      :
        type        : String
        validate    : require('../name').validateName
        set         : (value)-> value.toLowerCase()
      oldUsername   : String
      uid           :
        type        : Number
        set         : Math.floor
      email         :
        type        : String
        email       : yes
      password      : String
      salt          : String
      blockedUntil  : Date
      status        :
        type        : String
        enum        : [
          'invalid status type', [
            'unconfirmed','confirmed','blocked','deleted'
          ]
        ]
        default     : 'unconfirmed'
      registeredAt  :
        type        : Date
        default     : -> new Date
      lastLoginDate :
        type        : Date
        default     : -> new Date
      emailFrequency: Object
      onlineStatus  :
        actual      :
          type      : String
          enum      : ['invalid status',['online','offline']]
          default   : 'online'
        userPreference:
          type      : String
          # enum      : ['invalid status',['online','offline','away','busy']]

      sshKeys       : [Object]
      foreignAuth            :
        github               :
          foreignId          : String
          username           : String
          token              : String
          firstName          : String
          lastName           : String
          email              : String
        odesk                :
          foreignId          : String
          token              : String
          accessTokenSecret  : String
          requestToken       : String
          requestTokenSecret : String
          profileUrl         : String
        facebook             :
          foreignId          : String
          username           : String
          token              : String
    relationships       :
      ownAccount        :
        targetType      : JAccount
        as              : 'owner'
      leasedAccount     :
        targetType      : JAccount
        as              : 'leasor'
      emailConfirmation :
        targetType      : require '../emailconfirmation'
        as              : 'confirmation'

  sessions  = {}
  users     = {}
  guests    = {}

  @unregister = secure (client, confirmUsername, callback) ->
    {delegate} = client.connection
    if delegate.type is 'unregistered'
      return callback createKodingError "You are not registered!"
    unless confirmUsername is delegate.profile.nickname or
           delegate.can 'administer accounts'
      return callback createKodingError "You must confirm this action!"

    @createGuestUsername (err, username) =>
      return callback err  if err?
      email = "#{username}@koding.com"
      @fetchUser client, (err, user) =>
        return callback err  if err?
        userValues = {
          username
          email
          password        : createId()
          status          : 'deleted'
          registeredAt    : new Date 0
          lastLoginDate   : new Date 0
          onlineStatus    : 'offline'
          emailFrequency  : {}
          sshKeys         : []
          foreignAuth     : {}
        }
        modifier = { $set: userValues, $unset: { oldUsername: 1 }}
        user.update modifier, (err, docs) =>
          return callback err  if err?
          accountValues = {
            'profile.nickname'    : username
            'profile.firstName'   : 'a former'
            'profile.lastName'    : 'koding user'
            'profile.about'       : ''
            'profile.hash'        : getHash createId()
            'profile.avatar'      : ''
            'profile.experience'  : ''
            'profile.experiencePoints': 0
            'profile.lastStatusUpdate': ''
            type                  : 'deleted'
            ircNickame            : ''
            skillTags             : []
            locationTags          : []
            globalFlags           : ['deleted']
            onlineStatus          : 'offline'
          }
          delegate.update $set: accountValues, (err) =>
            return callback err  if err?
            @logout client, callback

  @isRegistrationEnabled =(callback)->
    JRegistrationPreferences = require '../registrationpreferences'
    JRegistrationPreferences.one {}, (err, prefs)->
      callback err? or prefs?.isRegistrationEnabled or no

  @authenticateClient:(clientId, context, callback)->
    JSession.one {clientId}, (err, session)=>
      if err
        callback createKodingError err
      else unless session?
        JSession.createSession (err, session, account)->
          return callback err  if err?
          callback null, account
      else
        {username} = session
        if username?
          JUser.one {username}, (err, user)=>
            if err
              callback createKodingError err
            else unless user?
              @logout clientId, callback
            else
              user.fetchAccount context, (err, account)->
                if err
                  callback createKodingError err
                else
                  #JAccount.emit "AccountAuthenticated", account
                  callback null, account
        else @logout clientId, callback


  getHash =(value)->
    require('crypto').createHash('md5').update(value.toLowerCase()).digest('hex')

  @setDefaultHash =->
    @all {}, (err, users)->
      users.forEach (user)->
        user.fetchOwnAccount (err, account)->
          account.profile.hash = getHash user.email
          account.save (err)-> throw err if err

  @whoami = secure ({connection:{delegate}}, callback)-> callback delegate

  checkBlockedStatus = (user, callback)->
    if user.status is 'blocked'
      if user.blockedUntil and user.blockedUntil > new Date
        toDate = user.blockedUntil.toUTCString()
        message = """
            You cannot login until #{toDate}.
            At least 10 moderators of Koding have decided that your participation is not of acceptable kind.
            That's all I know.
            You can demand further explanation from ban@koding.com. Please allow 1-2 days to receive a reply.
            Your machines might be blocked, all types of activities might be suspended.
            Your data is safe, you can access them when/if ban is lifted.
          """
        callback createKodingError message
      else
        user.unblock callback
    else
      callback null

  @login = secure ({connection}, credentials, callback)->
    {username, password, clientId} = credentials
    constructor = @
    JSession.one {clientId}, (err, session)->
      return callback err  if err
      # temp fix:
      # this broke login, reverted. - SY
      # if not session? or session.username isnt username
      unless session
        return callback createKodingError 'Could not restore your session!'

      bruteForceControlData =
        ip : session.clientIP
        username : username
      # todo add alert support(mail, log etc)
      JLog.checkLoginBruteForce bruteForceControlData, (res)->
        unless res then return callback createKodingError "Your login access is blocked for #{JLog.timeLimit()} minutes."
        JUser.one {username}, (err, user)->
          if err
            JLog.log { type: "login", username: username, success: no }, ->
              callback createKodingError err.message
          else unless user?
            JLog.log { type: "login", username: username, success: no }, ->
              callback createKodingError "Unknown user name"
          else unless user.getAt('password') is hashPassword password, user.getAt('salt')
            JLog.log { type: "login", username: username, success: no }, ->
              callback createKodingError 'Access denied!'
          else
            afterLogin connection, user, clientId, session, callback

  checkUserStatus = (user, account, callback)->
    if user.status is 'unconfirmed' and KONFIG.emailConfirmationCheckerWorker.enabled
      error = createKodingError "CONFIRMATION_WAITING"
      error.code = 403
      error.data or= {}
      error.data.name = account.profile.firstName or account.profile.nickname
      error.data.nickname = account.profile.nickname
      return callback error
    return callback null


  checkLoginConstraints = (user, account, callback)->
    checkBlockedStatus user, (err)->
      return callback err  if err
      checkUserStatus user, account, callback

  afterLogin = (connection, user, clientId, session, callback)->
    user.fetchOwnAccount (err, account)->
      if err then return callback err
      checkLoginConstraints user, account, (err)->
        if err then return callback err
        replacementToken = createId()
        session.update {
          $set            :
            username      : user.username
            lastLoginDate : new Date
            clientId      : replacementToken
          $unset:
            guestId       : 1
        }, (err)->
            return callback err  if err
            user.update { $set: lastLoginDate: new Date }, (err) ->
              return callback err  if err
              connection.delegate = account
              JAccount.emit "AccountAuthenticated", account
              # This should be called after login and this
              # is not correct place to do it, FIXME GG
              # p.s. we could do that in workers
              JLog.log { type: "login", username: account.username, success: yes }, ->
              account.updateCounts()
              callback null, {account, replacementToken}

  @logout = secure (client, callback)->
    if 'string' is typeof client
      sessionToken = client
    else
      {sessionToken} = client
      delete client.connection.delegate
      delete client.sessionToken
    JSession.remove { clientId: sessionToken }, callback

  @verifyEnrollmentEligibility = ({email, inviteCode}, callback)->
    JRegistrationPreferences = require '../registrationpreferences'
    JInvitation = require '../invitation'
    JRegistrationPreferences.one {}, (err, prefs)->
      if err
        callback err
      else unless prefs.isRegistrationEnabled
        callback new Error 'Registration is currently disabled!'
      else if inviteCode
        JInvitation.one {
          code: inviteCode
          status: $in : ['active','sent']
        }, (err, invite)->
          if err or !invite?
            callback createKodingError 'Invalid invitation ID!'
          else
            callback null, yes, invite
      else
        callback null, yes

  @addToGroup = (account, slug, email, invite, callback)->
    JGroup.one {slug}, (err, group)->
      if err or not group then callback err
      else
        group.approveMember account, (err)->
          return callback err  if err
          return invite.redeem connection:delegate:account, callback  if invite
          callback null

  @addToGroups = (account, invite, email, callback)->
    @addToGroup account, 'koding', email, invite, (err)=>
      if err then callback err
      else if invite?.group and invite?.group isnt 'koding'
        @addToGroup account, invite.group, email, invite, callback
      else
        callback null

  @createGuestUsername = (callback) ->
    ((require 'koding-counter') {
      db          : @getClient()
      counterName : 'guest'
      offset      : 0
    }).next (err, guestId) ->
      return callback err  if err?
      callback null, "guest-#{guestId}"

  @createTemporaryUser = (callback) ->
    @createGuestUsername (err, username) =>
      return callback err  if err?

      options     =
        username  : username
        email     : "#{username}@koding.com"
        password  : createId()

      @createUser options, (err, user, account) =>
        return callback err  if err?

        @addToGroup account, 'guests', null, null, (err) =>
          return callback err  if err?

          @configureNewAcccount account, user, createId(), callback

  @createUser = (userInfo, callback)->
    { username, email, password, firstName, lastName, foreignAuth,
      silence } = userInfo

    slug =
      slug            : username
      constructorName : 'JUser'
      usedAsPath      : 'username'
      collectionName  : 'jUsers'

    JName.claim username, [slug], 'JUser', (err)=>
      if err then callback err
      else
        salt = createSalt()
        user = new JUser {
          username
          email
          salt
          password: hashPassword(password, salt)
          emailFrequency: {
            global         : on
            daily          : on
            privateMessage : on
            followActions  : off
            comment        : on
            likeActivities : off
            groupInvite    : on
            groupRequest   : on
            groupApproved  : on
          }
        }

        user.foreignAuth = foreignAuth  if foreignAuth

        user.save (err)=>
          if err
            if err.code is 11000
              callback createKodingError "Sorry, \"#{email}\" is already in use!"
            else callback err
          else
            hash = getHash email
            account = new JAccount
              profile: {
                nickname: username
                firstName
                lastName
                hash
              }
            account.save (err)=>
              if err then callback err
              else user.addOwnAccount account, (err) ->
                return callback err  if err
                callback null, user, account

  @configureNewAcccount = (account, user, replacementToken, callback) ->
    JUser.emit 'UserCreated', user
    JAccount.emit "AccountAuthenticated", account
    callback null, {account, replacementToken}

  @fetchUserByProvider = (provider, session, callback)->
    {foreignAuth} = session
    unless foreignAuth
      return callback createKodingError "No foreignAuth:#{provider} info in session"

    query                                      = {}
    query["foreignAuth.#{provider}.foreignId"] = foreignAuth[provider].foreignId

    JUser.one query, callback

  @authenticateWithOauth = secure (client, resp, callback)->
    {isUserLoggedIn, provider} = resp
    {sessionToken} = client
    JSession.one {clientId: sessionToken}, (err, session) =>
      return callback err  if err
      kallback = (err, resp={}) ->
        {account, replacementToken} = resp
        callback err, {
          isNewUser : false
          userInfo  : null
          account
          replacementToken
        }
      @fetchUserByProvider provider, session, (err, user) =>
        return callback createKodingError err.message if err
        if isUserLoggedIn
          if user
            callback createKodingError """
              Account is already linked with another user.
            """
          else
            @fetchUser client, (err, user)=>
              @persistOauthInfo user.username, sessionToken, kallback
        else
          if user
            afterLogin client.connection, user, sessionToken, session, kallback
          else
            info = session.foreignAuth[provider]
            {username, email, firstName, lastName} = info
            callback null, {
              isNewUser : true,
              userInfo  : {username, email, firstName, lastName}
            }

  @validateAll = (userFormData, callback) =>

    validate = require './validators'

    isError = no
    errors = {}

    queue = Object.keys(userFormData).map (field) => =>
      if field of validate
        validate[field].call this, userFormData, (err) =>
          if err?
            errors[field] = err
            isError = yes
          queue.fin()
      else queue.fin()

    dash queue, -> callback(
      if isError
      then { message: "Errors were encountered during validation", errors }
      else null
    )

  @changePasswordByUsername = (username, password, callback) ->
    salt = createSalt()
    hashedPassword = hashPassword password, salt
    @update { username }, {
      $set: { salt, password: hashedPassword }
    }, callback

  @changeEmailByUsername = (options, callback) ->
    { account, oldUsername, email } = options
    @update { username: oldUsername }, { $set: { email }}, (err, res)=>
      return callback err  if err
      account.profile.hash = getHash email
      account.save (err)-> console.error if err
      callback null

  @changeUsernameByAccount = (options, callback)->
    { account, username, clientId, isRegistration } = options
    account.changeUsername { username, isRegistration }, (err) =>
      return callback err   if err?
      return callback null  unless clientId?
      newToken = createId()
      JSession.one { clientId }, (err, session) =>
        if err?
          return callback createKodingError "Could not update your session"

        if session?
          session.update { $set: { clientId: newToken, username }}, (err) ->
            return callback err  if err?
            callback null, newToken
        else
          callback createKodingError "Session not found!"

  @removeFromGuestsGroup = (account, callback) ->
    JGroup.one { slug: 'guests' }, (err, guestsGroup) ->
      return callback err  if err?
      unless guestsGroup?
        return callback createKodingError "Guests group not found!"
      guestsGroup.removeMember account, callback

  @convert = secure (client, userFormData, callback) ->
    { connection, sessionToken : clientId } = client
    { delegate : account } = connection
    { nickname : oldUsername } = account.profile
    { username, email, password, passwordConfirm, firstName, lastName,
      agree, inviteCode, referrer } = userFormData

    # only unreigstered accounts can be "converted"
    if account.status is "registered"
      return callback createKodingError "This account is already registered."

    if /^guest-/.test username
      return callback createKodingError "Reserved username!"

    newToken  = null
    invite    = null

    queue = [
      =>
        @validateAll userFormData, (err) =>
          return callback err  if err?
          queue.next()
      =>
        @changePasswordByUsername oldUsername, password, (err) =>
          return callback err  if err?
          queue.next()
      =>
        options = { account, oldUsername, email }
        @changeEmailByUsername options, (err) =>
          return callback err  if err?
          queue.next()
      =>
        @persistOauthInfo oldUsername, client.sessionToken, (err)=>
          return callback err  if err
          queue.next()
      =>
        options = { account, username, clientId, isRegistration: yes }
        @changeUsernameByAccount options, (err, newToken_) =>
          return callback err  if err?
          newToken = newToken_
          queue.next()
      =>
        @verifyEnrollmentEligibility {email, inviteCode}, (err, isEligible, invite_) =>
          return callback err  if err
          invite = invite_
          queue.next()
      =>
        @addToGroups account, invite, email, (err) =>
          return callback err  if err?
          queue.next()
      =>
        @removeFromGuestsGroup account, (err) =>
          return callback err  if err?
          queue.next()
      ->
        account.update $set: {
          'profile.firstName' : firstName
          'profile.lastName'  : lastName
          type                : 'registered'
        }, (err) ->
          return callback err  if err?
          queue.next()
      =>
        @sendEmailConfirmationByUsername username, (err) =>
          return console.error err if err
          queue.next()
      ->
        JAccount.emit "AccountRegistered", account, referrer
        queue.next()
      =>
        callback null, newToken
        queue.next()
    ]

    daisy queue

  @removeUnsubscription:({email}, callback)->
    JUnsubscribedMail = require '../unsubscribedmail'
    JUnsubscribedMail.one {email}, (err, unsubscribed)->
      return callback err  if err or not unsubscribed
      unsubscribed.remove callback

  @grantInitialInvitations = (username)->
    JInvitation.grant {'profile.nickname': username}, 3, (err)->
      console.log 'An error granting invitations', err if err

  @fetchUser = secure (client, callback)->
    JSession.one {clientId: client.sessionToken}, (err, session)->
      if err
        callback err
      else
        {username} = session

        if username?
          JUser.one {username}, (err, user)->
            callback null, user
        else
          callback null

  @changePassword = secure (client,password,callback)->
    @fetchUser client, (err,user)->
      user.changePassword password, callback
      email = new JMail {
        email: user.email
        subject : "Your password has changed"
        content : """
Your password has been changed!  If you didn't request this change, please contact support@koding.com immediately!
"""
      }
      email.save()

  @changeEmail = secure (client,options,callback)->

    {email} = options

    @emailAvailable email, (err, res)=>

      if err
        callback createKodingError "Something went wrong please try again!"
      else if res is no
        callback createKodingError "Email is already in use!"
      else
        @fetchUser client, (err,user)->
          account = client.connection.delegate
          user.changeEmail account, options, callback
          email = new JMail {
            email: user.email
            subject : "Your email has changed"
            content : """
    Your email has been changed!  If you didn't request this change, please contact support@koding.com immediately!
    """
          }
          email.save()

  @emailAvailable = (email, callback)->
    @count {email}, (err, count)->
      if err
        callback err
      else if count is 1
        callback null, no
      else
        callback null, yes

  @usernameAvailable = (username, callback)->
    JName = require '../name'

    username += ''
    res =
      kodingUser   : no
      forbidden    : yes

    JName.count { name: username }, (err, count)=>
      if err or username.length < 4 or username.length > 25
        callback err, res
      else
        res.kodingUser = if count is 1 then yes else no
        res.forbidden = if username in @bannedUserList then yes else no
        callback null, res

  fetchContextualAccount:(context, rest..., callback)->
    # Relationship.one {
    #   as          : 'owner'
    #   sourceId    : @getId()
    #   targetName  : 'JAccount'
    #   'data.context': context
    # }, (err, account)=>
    #   if err
    #     callback err
    #   else if account?
    #     callback null, account
    #   else
    #     @fetchOwnAccount rest..., callback

  fetchAccount:(context, rest...)->
    @fetchOwnAccount rest...
    # if context is 'koding' then @fetchOwnAccount rest...
    # else @fetchContextualAccount context, rest...

  changePassword:(newPassword, callback)->
    salt = createSalt()
    @update $set: {
      salt
      password: hashPassword(newPassword, salt)
    }, callback

  changeEmail:(account, options, callback)->

    JVerificationToken = require '../verificationtoken'

    {email, pin} = options

    if not pin
      options =
        action    : "update-email"
        user      : @
        email     : email

      JVerificationToken.requestNewPin options, callback

    else
      options =
        action    : "update-email"
        username  : @getAt 'username'
        email     : email
        pin       : pin

      JVerificationToken.confirmByPin options, (err, confirmed)=>

        if err then callback err
        else if confirmed
          @update $set: {email}, (err, res)=>
            if err
              callback err
            else
              account.profile.hash = getHash email
              account.save (err)-> throw err if err
              callback null
        else
          callback createKodingError 'PIN is not confirmed.'

  fetchHomepageView:(account, callback)->
    @fetchAccount 'koding', (err, account)->
      if err then callback err
      else account.fetchHomepageView account, callback

  sendEmailConfirmation:(callback=->)->
    JEmailConfirmation = require '../emailconfirmation'
    JEmailConfirmation.createAndSendEmail @, callback

  confirmEmail: (callback)->
    @update {$set: status: 'confirmed'}, (err, res)=>
      return callback err if err
      JUser.emit "EmailConfirmed", @
      return callback null

  block:(blockedUntil, callback)->
    unless blockedUntil then return callback createKodingError "Blocking date is not defined"
    @update
      $set:
        status: 'blocked',
        blockedUntil : blockedUntil
    , (err) =>
        return callback err if err
        JUser.emit "UserBlocked", @
        return callback err

  unblock:(callback)->
    @update
      $set            :
        status        : 'unconfirmed',
        blockedUntil  : new Date()
    , (err) =>
      return callback err if err

      JUser.emit "UserUnblocked", @
      return callback err

  @persistOauthInfo: (username, clientId, callback)->
    @extractOauthFromSession clientId, (err, foreignAuthInfo, session)=>
      return callback err  if err
      return callback()    unless foreignAuthInfo
      @saveOauthToUser foreignAuthInfo, username, (err)=>
        return callback err  if err
        @clearOauthFromSession session, (err)=>
          return callback err  if err
          @copyPublicOauthToAccount username, foreignAuthInfo, callback

  @extractOauthFromSession: (clientId, callback)->
    JSession.one {clientId: clientId}, (err, session)->
      return callback err  if err

      {foreignAuth, foreignAuthType} = session
      if foreignAuth and foreignAuthType
        callback null, {foreignAuth, foreignAuthType}, session
      else
        callback() # WARNING: don't assume it's an error if there's no foreignAuth

  @saveOauthToUser: ({foreignAuth, foreignAuthType}, username, callback)->
    query = {}
    query["foreignAuth.#{foreignAuthType}"] = foreignAuth[foreignAuthType]

    @update {username}, $set: query, callback

  @clearOauthFromSession: (session, callback)->
    session.update $unset: {foreignAuth: "", foreignAuthType:""}, callback

  @copyPublicOauthToAccount: (username, {foreignAuth, foreignAuthType}, callback)->
    JAccount.one {"profile.nickname":username}, (err, account)->
      return callback err  if err

      name    = "ext|profile|#{foreignAuthType}"
      content = foreignAuth[foreignAuthType].profile
      account._store {name, content}, callback

  @setSSHKeys: secure (client, sshKeys, callback)->
    @fetchUser client, (err,user)->
      user.sshKeys = sshKeys
      user.save callback

  @getSSHKeys: secure (client, callback)->
    @fetchUser client, (err,user)->
      callback user.sshKeys or []

  @sendEmailConfirmationByUsername:(username, callback)->
    @one {username}, (err, user)->
      return callback err  if err
      user.sendEmailConfirmation callback
