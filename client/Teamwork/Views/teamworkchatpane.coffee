class TeamworkChatPane extends ChatPane

  constructor: (options = {}, data) ->

    super options, data

    @setClass "tw-chat"
    @getDelegate().setClass "tw-chat-open"

  createDock: ->
    @dock = new KDCustomHTMLView cssClass: "hidden"

  updateCount: (count) ->

  createMessage: ->
    message  = @input.getValue()
    if @isSystemMessage message
      @sendMessage message: message, no, yes
      @runSystemMessageHandler message
      @emit "NewChatItemPosted"
    else
      super

  sendMessage: (messageData, isSystemMessage, slientlyHandle) ->
    cssClass   = ""
    nickname   = KD.nick()

    if isSystemMessage
      cssClass = "tw-bot-message"
      nickname = "teamwork"

    message    =
      user     : { nickname }
      time     : Date.now()
      body     : messageData.message
      by       : messageData.by
      cssClass : cssClass            or ""
      system   : isSystemMessage     or no

    if   isSystemMessage or slientlyHandle then @addNew message
    else @chatRef.child(message.time).set message

  createNewChatItem: (params) ->
    return if @shouldBeHidden_ params

    super

  appendToChatItem: (params) ->
    return if @shouldBeHidden_ params

    super

  shouldBeHidden_: (params) ->
    {details}       = params
    isSystemMessage = details.system
    originUser      = details.by

    return originUser is KD.nick() and isSystemMessage

  isSystemMessage: (message) ->
    return  unless message
    splitted     = message.trim().split " "
    keyword      = splitted.first
    hasMaxLength = splitted.length is 2
    hasHandler   = replyHandlers[keyword] isnt undefined
    isHelp       = keyword is "help"
    isStopWatch  = keyword is "stop"
    isInvite     = keyword is "invite"

    if isHelp
      return splitted.length is 1
    else if isStopWatch
      return message is "stop watching"
    else if isInvite
      return hasHandler
    else
      return hasMaxLength and hasHandler

  runSystemMessageHandler: (message) ->
    splitted = message.split " "
    [key]    = splitted

    splitted.shift() # remove first item and update the array instance
    @[replyHandlers[key]] splitted

  replyForSystemHelp: ->
    @botReply messages.help

  replyForJoin: (sessionKey) ->
    return if sessionKey.length > 1
    # TODO: fatihacet - we need to use a regex to check it's a real sessionKey
    sessionKey = sessionKey.first

    if sessionKey.indexOf("_") > -1
      @botReply getMessage "validateKey", sessionKey
      @workspace.firebaseRef.child(sessionKey).once "value", (snapshot) =>
        if snapshot.val() is null or not snapshot.val().keys
          @botReply messages.noSession
        else
          @botReply getMessage "joinSession", sessionKey
          @workspace.getDelegate().emit "JoinSessionRequested", sessionKey
    else
      # TODO: fatihacet - implement getting the sessionKey via username
      @botReply messages.invalidKey

  replyForInvite: (usernames) ->
    query = { "profile.nickname": { "$in": usernames } }

    KD.remote.api.JAccount.someWithRelationship query, {}, (err, accounts) =>
      stack = []
      usernames.forEach (username) =>
        account = null
        user    = account for account in accounts when account.profile.nickname is username

        if user
          stack.push (cb) =>
            @workspace.createUserList() # TODO: fatihacet - find a better way for invite

            @workspace.userList.once "UserInvited", =>
              @botReply getMessage "invited", username

            @workspace.userList.sendInviteTo account
        else
          @botReply getMessage "inviteFailed", username

      async.parallel stack, noop

  replyForWatch: (usernames) ->
    username = usernames.first
    return if usernames.length is 0 or usernames.first.trim is ""

    # TODO: fatihacet - I need to check username is valid and user is in session.
    @workspace.setWatchMode username
    @botReply getMessage "watchReply", username

  replyForStopWatching: ->
    @workspace.setWatchMode "nobody"
    @botReply getMessage "watchNobody"

  botReply: (message) ->
    messageData =
      message   : message
      by        :
        nickname: "teamwork"

    @sendMessage messageData, yes

  sendWelcomeMessage: ->
    @botReply messages.welcome

  viewAppended: ->
    super

    links      = new KDCustomHTMLView
      cssClass : "tw-action-links"

    links.addSubView new KDCustomHTMLView
      tagName  : "p"
      partial  : "Active users"

    links.addSubView new KDCustomHTMLView
      tagName  : "p"
      cssClass : "tw-share-link"
      partial  : "Share"
      click    : => new TeamworkShareModal delegate: @getDelegate()

    @avatars   = @workspace.avatarsView = new KDCustomHTMLView
      cssClass : "tw-users"

    @addSubView @avatars, null, yes
    @avatars.addSubView links, null, yes

    tipTitle   = if @workspace.amIHost() then messages.host else messages.you

    @avatars.addSubView new AvatarStaticView
      size     :
        width  : 30
        height : 30
      tooltip  :
        title  : tipTitle
    , KD.whoami()

    @avatars.addSubView new KDCustomHTMLView
      cssClass : "tw-bot-avatar"
      tooltip  :
        title  : messages.botTooltip

    if @getDelegate().amIHost()
      @avatars.addSubView new KDCustomHTMLView
        cssClass : "tw-add-user"
        tooltip  :
          title  : "Click here to invite your friends"
        click    : => new TeamworkInviteModal delegate: this

  getMessage = (key, data) ->
    return messages[key].replace "$0", data

  # class scope variables
  replyHandlers   =
    help          : "replyForSystemHelp"
    invite        : "replyForInvite"
    watch         : "replyForWatch"
    join          : "replyForJoin"
    stop          : "replyForStopWatching"

  messages        =
    welcome       : """
        Hello earthling! My name is TBot. I love keyboard commands.
        I can bring others to work with you from far far away.
        For a list of things that I can help you with, type 'help'
      """
    botTooltip    : """ Hi there, My name is TBot. I am here to assist you. If you need help, just type "help" """
    host          : "You are the host of this session"
    you           : "This is you"
    watchReply    : """
        Ok. Now you are now watching $0. Seems like a nice guy.
        You can type "stop watching" anytime.
      """
    watchNobody   : "It's done. Now you are watching nobody."
    invited       : "I invited $0 for you. I will let you know when they join."
    inviteFailed  : "Sorry, are you sure your friend's nickname is $0? Because I can't find it."
    validateKey   : "01001101 ... I am checking this session key, $0."
    joinSession   : "01001010 ... Joining session, $0"
    noSession     : "Sorry, looks like this session is closed by its host, I cannot get you in."
    invalidKey    : "Sorry, looks like this session key is not valid anymore."
    help          : """
        If you type,
        "invite username" I can bring someone to your session,
        "watch username"  I will show you their changes in realtime,
        "join sessionKey" I will take you to that session.
        Try me!
      """