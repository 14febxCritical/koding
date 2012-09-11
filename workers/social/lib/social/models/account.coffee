jraphical = require 'jraphical'

KodingError = require '../error'

module.exports = class JAccount extends jraphical.Module
  log4js          = require "log4js"
  log             = log4js.getLogger("[JAccount]")

  @trait __dirname, '../traits/followable'
  @trait __dirname, '../traits/filterable'
  @trait __dirname, '../traits/taggable'
  @trait __dirname, '../traits/notifiable'
  @trait __dirname, '../traits/flaggable'

  JAppStorage = require './appstorage'
  
  @getFlagRole = 'content'

  {ObjectId,secure,race,dash} = require 'bongo'
  {Relationship} = jraphical
  @share()
  Experience = 
    company           : String
    website           : String
    position          : String
    type              : String
    fromDate          : String
    toDate            : String
    description       : String
    # endorsements      : [
    #       endorser    : String
    #       title       : String
    #       text        : String
    #     ]
  @set
    emitFollowingActivities : yes # create buckets for follower / followees
    tagRole             : 'skill'
    taggedContentRole   : 'developer'
    indexes:
      'profile.nickname' : 'unique'
    sharedMethods :
      static      : [
        'one', 'some', 'someWithRelationship'
        'someData', 'getAutoCompleteData', 'count'
        'byRelevance'
      ]
      instance    : [
        'on','modify','follow','unfollow','fetchFollowersWithRelationship'
        'fetchFollowingWithRelationship',
        'fetchMounts','fetchActivityTeasers','fetchRepos','fetchDatabases'
        'fetchMail','fetchNotificationsTimeline','fetchActivities'
        'fetchStorage','count','addTags','fetchLimit'
        'fetchFollowedTopics', 'fetchKiteChannelId', 'setEmailPreferences'
        'fetchNonces', 'glanceMessages', 'glanceActivities', 'fetchRole'
        'fetchAllKites','flagAccount','unflagAccount'
      ]
    schema                  :
      skillTags             : [String]
      locationTags          : [String]
      systemInfo            :
        defaultToLastUsedEnvironment :
          type              : Boolean
          default           : yes
      # counts                : Followable.schema.counts
      counts                :
        followers           :
          type              : Number
          default           : 0
        following           :
          type              : Number
          default           : 0
        topics              :
          type              : Number
          default           : 0
      environmentIsCreated  : Boolean
      profile               :
        about               : String
        nickname            :
          type              : String
          validate          : (value)->
            3 < value.length < 26 and /^[a-z0-9][a-z0-9-]+$/.test value
          set               : (value)-> value.toLowerCase()
        hash                :
          type              : String
          # email             : yes
        ircNickname         : String
        firstName           :
          type              : String
          required          : yes
          
        lastName            : 
          type              : String
          default           : ''
        description         : String
        avatar              : String
        status              : String
        experience          : String
        experiencePoints    :
          type              : Number
          default           : 0
        lastStatusUpdate    : String
      globalFlags           : [String]
      meta                  : require 'bongo/bundles/meta'
    relationships           :

      mount         :
        as          : 'owner'
        targetType  : "JMount"

      repo          :
        as          : 'owner'
        targetType  : "JRepo"

      # database      :
      #   as          : 'owner'
      #   targetType  : JDatabase

      follower      :
        as          : 'follower'
        targetType  : "JAccount"

      # followee      :
      #   as          : 'followee'
      #   targetType  : JAccount
      
      activity      :
        as          : 'activity'
        targetType  : "CActivity"
      
      # privateMessage:
      #   as          : ['recipient','sender']
      #   targetType  : JPrivateMessage

      appStorage    :
        as          : 'appStorage'
        targetType  : "JAppStorage"
      
      limit:
        as          : 'invite'
        targetType  : "JLimit"
      
      tag:
        as          : 'skill'
        targetType  : "JTag"
      
      content       :
        as          : 'creator'
        targetType  : ["CActivity", "JStatusUpdate", "JCodeSnip", "JComment"]

  @findSuggestions = (seed, options, callback)->
    {limit,blacklist}  = options
    
    @some {
      $or : [
          ( 'profile.nickname'  : seed )
          ( 'profile.firstName' : seed )
          ( 'profile.lastName'  : seed )
        ],
      _id     :
        $nin  : blacklist
    },{
      limit
      sort    : 'profile.firstName' : 1
    }, callback

  @getAutoCompleteData = (fieldString, queryString, callback)->
    query = {}
    desiredData = {}
    query[fieldString] = RegExp queryString, 'i'
    desiredData[fieldString] = yes
    @someData query, desiredData, (err, cursor)->
      cursor.toArray (err, docs)->
        results = []
        for doc in docs
          results.push doc.profile.fullname
        callback err, results
  
  setEmailPreferences: secure (client, prefs, callback)->
    JUser.fetchUser client, (err, user)->
      if err
        callback err
      else
        Object.keys(prefs).forEach (granularity)->
          prefs[granularity] = if prefs[granularity] then 'instant' else 'never'
        user.update {$set: emailFrequency: prefs}, callback
  
  glanceMessages: secure (client, callback)->
  
  glanceActivities: secure (client, callback)->
    @fetchActivities {'data.flags.glanced': $ne: yes}, (err, activities)->
      if err
        callback err
      else
        queue = activities.map (activity)->
          -> activity.mark client, 'glanced', -> queue.fin()
        dash queue, callback
  
  fetchNonces: secure (client, callback)->
    {delegate} = client.connection
    unless @equals delegate
      callback new KodingError 'Access denied.'
    else
      client.connection.remote.fetchClientId (clientId)->
        JSession.one {clientId}, (err, session)->
          if err
            callback err
          else
            nonces = (hat() for i in [0...10])
            session.update $addToSet: nonces: $each: nonces, (err)->
              if err
                callback err
              else
                callback null, nonces
  
  fetchKiteChannelId: secure (client, kiteName, callback)->
    {delegate} = client.connection
    unless delegate instanceof JAccount
      callback new KodingError 'Access denied.'
    else
      callback null, "private-#{kiteName}-#{delegate.profile.nickname}"

  dummyAdmins = ["sinan", "devrim", "aleksey", "gokmen", "chris"]

  flagAccount: secure (client, flag, callback)->
    {delegate} = client.connection
    JAccount.taint @getId()
    if delegate.can 'flag', this
      @update {$addToSet: globalFlags: flag}, callback
      if flag is 'exempt'
        console.log 'is exempt'
        @markAllContentAsLowQuality()
      else
        console.log 'aint exempt'
    else
      callback new KodingError 'Access denied'
  
  unflagAccount: secure (client, flag, callback)->
    {delegate} = client.connection
    JAccount.taint @getId()
    if delegate.can 'flag', this
      @update {$pullAll: globalFlags: [flag]}, callback
      if flag is 'exempt'
        console.log 'is exempt'
        @unmarkAllContentAsLowQuality()
      else
        console.log 'aint exempt'
    else
      callback new KodingError 'Access denied'
  
  checkFlag:(flag)->
    flags = @getAt('globalFlags')
    flags and (flag in flags)
  
  isDummyAdmin = (nickname)-> if nickname in dummyAdmins then yes else no
  
  @getFlagRole =-> 'owner'
  
  can:(action, target)->
    switch action
      when 'delete','flag'
        @profile.nickname in dummyAdmins or target.originId?.equals @getId()
  
  fetchRole: secure ({connection}, callback)->
    
    if isDummyAdmin connection.delegate.profile.nickname
      callback null, "super-admin"
    else
      callback null, "regular"

  fetchAllKites: secure ({connection}, callback)->

    if isDummyAdmin connection.delegate.profile.nickname
      callback null,
        sharedHosting :
          hosts       : ["cl0", "cl1", "cl2", "cl3"]
        Databases     :
          hosts       : ["cl0", "cl1", "cl2", "cl3"]
        terminal      :
          hosts       : ["cl0", "cl1", "cl2", "cl3"]
    else
      callback new KodingError "Permission denied!"

  # temp dummy stuff ends

  fetchPrivateChannel:(callback)->
    require('bongo').fetchChannel @getPrivateChannelName(), callback
  
  getPrivateChannelName:-> "private-#{@getAt('profile.nickname')}-private"

  addTags: secure (client, tags, callback)->
    Taggable::addTags.call @, client, tags, (err)->
      if err then callback err
      else callback null
  
  fetchMail:do ->
    collectParticipants = (messages, delegate, callback)->
      fetchParticipants = race (i, message, fin)->
        register = new Register # a register per message...
        jraphical.Relationship.all 
          targetName  : 'JPrivateMessage', 
          targetId    : message.getId(), 
          sourceId    : 
            $ne       : delegate.getId()
        , (err, rels)->
          if err
            callback err
          else
            # only include unique participants.
            message.participants = (rel for rel in rels when register.sign rel.sourceId)
            fin()
      , callback
      fetchParticipants(message) for message in messages when message?
    
    secure ({connection}, options, callback)->
      [callback, options] = [options, callback] unless callback
      unless @equals connection.delegate
        callback new KodingError 'Access denied.'
      else
        options or= {}
        selector = 
          if options.as
            as: options.as
          else
            {}
        options.limit     = 8
        options.fetchMail = yes
        @fetchPrivateMessages selector, options, (err, messages)->
          if err
            callback err
          else
            collectParticipants messages, connection.delegate, (err)->
              if err
                callback err
              else
                callback null, messages
  
  fetchNotificationsTimeline: secure ({connection}, selector, options, callback)->
    unless @equals connection.delegate
      callback new KodingError 'Access denied.'
    else
      @fetchActivities selector, options, @constructor.collectTeasersAllCallback callback
  
  fetchActivityTeasers : secure ({connection}, selector, options, callback)->
    unless @equals connection.delegate
      callback new KodingError 'Access denied.'
    else
      @fetchActivities selector, options, callback
  
  modify: secure (client, fields, callback) ->
    if @equals(client.connection.delegate) and 'globalFlags' not in Object.keys(fields)
      @update $set: fields, callback
  
  oldFetchMounts = @::fetchMounts
  fetchMounts: secure (client,callback)->
    if @equals client.connection.delegate
      oldFetchMounts.call @,callback
    else
      callback new KodingError "access denied for guest."

  oldFetchRepos = @::fetchRepos  
  fetchRepos: secure (client,callback)->
    if @equals client.connection.delegate
      oldFetchRepos.call @,callback
    else
      callback new KodingError "access denied for guest."    

  oldFetchDatabases = @::fetchDatabases  
  fetchDatabases: secure (client,callback)->
    if @equals client.connection.delegate
      oldFetchDatabases.call @,callback
    else
      callback new KodingError "access denied for guest."

  setClientId:(@clientId)->
  
  getFullName:->
    {profile} = @data
    profile.firstName+' '+profile.lastName
  
  fetchStorage: secure (client, options, callback)->
    account = @
    unless @equals client.connection.delegate
      return callback "Attempt to access unauthorized application storage"
    
    {appId, version} = options
    @fetchAppStorage {}, {targetOptions:query:{appId}}, (error, storage)->
      if error then callback error
      else
        unless storage?
          log.info 'creating new storage for application', appId, version
          newStorage = new JAppStorage {appId, version}
          newStorage.save (error) =>
            if error then callback error
            else
              account.addAppStorage newStorage, (err)->
                callback err, newStorage
        else
          callback error, storage
  
  markAllContentAsLowQuality:->
    @fetchContents (err, contents)->
      contents.forEach (item)->
        item.update {$set: isLowQuality: yes}, console.log
        item.emit 'ContentMarkedAsLowQuality', null
  
  unmarkAllContentAsLowQuality:->
    @fetchContents (err, contents)->
      contents.forEach (item)->
        item.update {$set: isLowQuality: no}, console.log
        item.emit 'ContentUnmarkedAsLowQuality', null
  
  @taintedAccounts = {}
  @taint =(id)->
    @taintedAccounts[id] = yes
  
  @untaint =(id)->
    delete @taintedAccounts[id]
  
  @isTainted =(id)->
    isTainted = @taintedAccounts[id]
    isTainted

  # koding.pre 'methodIsInvoked', (client, callback)=>
  #   delegate = client?.connection?.delegate
  #   id = delegate?.getId()
  #   unless id
  #     callback client
  #   else if @isTainted id
  #     JAccount.one _id: id, (err, account)=>
  #       if err
  #         console.log 'there was an error'
  #       else
  #         @untaint id
  #         client.connection.delegate = account
  #         console.log 'delegate is force-loaded from db'
  #         callback client
  #   else
  #     callback client