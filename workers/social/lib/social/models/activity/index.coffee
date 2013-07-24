jraphical      = require 'jraphical'

Graph          = require "../graph/graph"

KodingError = require '../../error'

module.exports = class CActivity extends jraphical.Capsule
  {Base, ObjectId, race, dash, secure} = require 'bongo'
  {Relationship} = jraphical

  {groupBy} = require 'underscore'

  {permit} = require '../group/permissionset'

  @getFlagRole =-> 'activity'

  jraphical.Snapshot.watchConstructor this

  @share()

  @trait __dirname, '../../traits/followable', override: no
  @trait __dirname, '../../traits/protected'
  @trait __dirname, '../../traits/restrictedquery'
  @trait __dirname, '../../traits/grouprelated'

  @set
    softDelete        : yes
    feedable          : yes
    broadcastable     : no
    indexes           :
      'sorts.repliesCount'  : 'sparse'
      'sorts.likesCount'    : 'sparse'
      'sorts.followerCount' : 'sparse'
      createdAt             : 'sparse'
      modifiedAt            : 'sparse'
      group                 : 'sparse'

    permissions             :
      'read activity'       :
        public              : ['guest','member','moderator']
        private             : ['member','moderator']
    sharedMethods     :
      static          : [
        'fetchFolloweeContents'
        'one','some','someData','each','cursor','teasers'
        'captureSortCounts','addGlobalListener','fetchFacets'
        'checkIfLikedBefore', 'count', 'fetchCount'
        'fetchPublicActivityFeed', 'fetchUsersActivityFeed',
        'fetchLastActivityTimestamp', 'testRevive'
      ]
      instance        : ['fetchTeaser']
    schema            :
      # teaserSnapshot  : Object
      sorts           :
        repliesCount  :
          type        : Number
          default     : 0
        likesCount    :
          type        : Number
          default     : 0
        followerCount :
          type        : Number
          default     : 0
      isLowQuality    : Boolean
      snapshot        : String
      snapshotIds     : [ObjectId]
      createdAt       :
        type          : Date
        default       : -> new Date
      modifiedAt      :
        type          : Date
        get           : -> new Date
      originType      : String
      originId        : ObjectId
      group           : String

  # this is for revival test...
  # TODO: dont forget to remove it
  @testRevive: (options, callback)->
    query = 'start koding=node:koding(id=\'5196fcb0bc9bdb0000000011\')
    MATCH koding<-[:follower]-myfollowees-[:author]-content
    where myfollowees.name="JAccount"
    AND content.group = "koding"
    AND (content.name=\'JStatusUpdate\')
    return distinct content
    order by content.`meta.createdAtEpoch` DESC
    LIMIT 1'
    ret = []
    try
      Graph   = require "../graph/graph"
      graph = new Graph({config:KONFIG['neo4j']})
      graph.db.query query, {}, (err, results) ->
        resultData = (result.content.data for result in results)
        graph.objectify resultData, (objecteds)=>
          graph.revive objecteds, (revived)->
            callback null, revived
    catch e 
      console.log ">>>>", e 

    #callback null, "foo"

  @on 'feed-new', (activities)->
    JGroup = require '../group'
    grouped = groupBy activities, 'group'
    for own groupName, items of grouped
      JGroup.broadcast groupName, 'feed-new', items

  @fetchLastActivityTimestamp = (callback) ->
    selector  = {}
    fields    = createdAt: 1
    options   = limit:1, sort: createdAt: -1
    @each selector, fields, options, (err, item)->
      return callback err  if err
      callback null, +item.createdAt  if item?

  # @__migrate =(callback)->
  #   @all {snapshot: $exists: no}, (err, activities)->
  #     console.log('made it here')
  #     if err
  #       callback err
  #     else
  #       activities.forEach (activity)->
  #         activity.fetchSubject (err, subject)->
  #           if err
  #             callback err
  #           else
  #             subject.fetchTeaser (err, teaser)->
  #               if err
  #                 callback err
  #               else
  #                 activity.update
  #                   $set:
  #                     snapshot: JSON.stringify(teaser)
  #                   $addToSet:
  #                     snapshotIds: subject.getId()
  #                 , callback

  @fetchCacheCursor =(options = {}, callback)->

    {to, from, lowQuality, types, limit, sort} = options

    selector =
      group        : 'koding'
      createdAt    :
        $lt        : new Date to
        $gt        : new Date from
      type         :
        $in        : types
      isLowQuality :
        $ne        : not lowQuality

    fields  =
      type      : 1
      createdAt : 1

    options =
      sort  : sort  or {createdAt: -1}
      limit : limit or 1000

    @someData selector, fields, options, (err, cursor)->
      if err then callback err
      else
        callback null, cursor

  @fetchRangeForCache = (options = {}, callback)->
    @fetchCacheCursor options, (err, cursor)->
      if err then console.warn err
      else
        cursor.toArray (err, arr)->
          if err then callback err
          else
            callback null, arr

  @captureSortCounts =(callback)->
    selector = {
      type: {$in: ['CStatusActivity','CLinkActivity','CCodeSnipActivity',
                   'CDiscussionActivity','COpinionActivity',
                   'CCodeShareActivity','CTutorialActivity',
                   'CBlogPostActivity']}
      $or: [
        {'sorts.repliesCount' : $exists:no}
        {'sorts.likesCount'   : $exists:no}
      ]
    }
    @someData selector, {
      _id: 1
    }, (err, cursor)->
      if err
        callback err
      else
        queue = []
        cursor.each (err, doc)->
          if err
            callback err
          else unless doc?
            dash queue, callback
          else
            {_id} = doc
            queue.push ->
              selector2 = {
                sourceId  : _id
                as        : 'content'
              }
              Relationship.someData selector2, {
                targetName  : 1
                targetId    : 1
              }, (err, cursor)->
                if err
                  callback err
                else
                  cursor.nextObject (err, doc1)->
                    if err
                      queue.fin(err)
                    else unless doc1?
                      console.log _id, JSON.stringify selector2
                    else
                      {targetName, targetId} = doc1
                      Base.constructors[targetName].someData {
                        _id: targetId
                      },{
                        'repliesCount'  : 1
                        'meta'          : 1
                      }, (err, cursor)->
                        if err
                          queue.fin(err)
                        else
                          cursor.nextObject (err, doc2)->
                            if err
                              queue.fin(err)
                            else
                              {repliesCount, meta} = doc2
                              op = $set:
                                 'sorts.repliesCount' : repliesCount
                                 'sorts.likesCount'   : meta?.likes or 0
                              CActivity.update {_id}, op, -> queue.fin()

  fetchTeaser:(callback, showIsLowQuality=no)->
    @fetchSubject (err, subject)->
      if err
        callback err
      else
        subject.fetchTeaser (err, teaser)->
          callback err, teaser
        , showIsLowQuality

  @teasers =(selector, options, callback)->
    [callback, options] = [options, callback] unless callback
    @someData {snapshot:$exists:1}, {snapshot:1}, {limit:20}, (err, cursor)->
      cursor.toArray (err, arr)->
        callback null, 'feed:'+(item.snapshot for item in arr).join '\n'

  defaultFacets = [
      'CStatusActivity'
      'CCodeSnipActivity'
      'CFollowerBucketActivity'
      'CNewMemberBucketActivity'
      'CDiscussionActivity'
      'CTutorialActivity'
      'CInstallerBucketActivity'
      'CBlogPostActivity'
    ]

  neo4jFacets = [
    "JLink"
    "JBlogPost"
    "JTutorial"
    "JStatusUpdate"
    "JComment"
    "JOpinion"
    "JDiscussion"
    "JCodeSnip"
    "JCodeShare"
  ]

  @fetchCount = permit 'read activity',
    success:(client, callback)-> @count callback

  @fetchFacets = permit 'read activity',
    success:(client, options, callback)->
      {to, limit, facets, lowQuality, originId, sort, skip} = options
      lowQuality  ?= yes
      facets      ?= defaultFacets
      to          ?= Date.now()

      selector =
        type         : { $in : facets }
        createdAt    : { $lt : new Date to }
        group        : client.groupName ? 'koding'

      selector.originId = originId if originId
      selector.isLowQuality = $ne : yes unless lowQuality

      options =
        limit : limit ? 20
        sort  : sort  or createdAt : -1
        skip  : skip  ? 0

      @some selector, options, (err, activities)->
        if err then callback err
        else

          # When the snapshot already contains &quot;, those will be
          # decoded once the client receives them (along with the " that
          # are encoded for the server-client transmission). That's why
          # they are converted into \" here.              02/28/13 Arvid

          for own index,activity of activities
            if activity.snapshot
              activities[index].snapshot = activities[index].snapshot.replace(/(&quot;)/g, '\\"')

          callback null, activities

  @getCurrentGroup: (client, callback)->
    {delegate} = client.connection
    if not delegate
      callback callback {error: "Request not valid"}
    else
      groupName = client.context.group
      JGroup = require '../group'
      JGroup.one slug : groupName, (err, group)=>
        if err then return callback err
        unless group then return callback {error: "Group not found"}
        group.canReadActivity client, (err, res)->
          if err then return callback {error: "Not allowed to open this group"}
          else callback null, group

  # this is used for activities on profile page
  @fetchUsersActivityFeed: secure (client, options, callback)->
    @getCurrentGroup client, (err, group)=>
      if err then return callback err
      {Activity} = require "../graph"
      options.client = client
      options.group = group

      Activity.fetchUsersActivityFeed options, callback

      return   
      userId = client.connection.delegate.getId()
      {facets, to, limit} = options
      limit = 5 #bandage for now

      groupId = group._id
      groupName = group.slug

      query = [
        "start koding=node:koding(id='#{options.originId}')"
        'MATCH koding<-[:author]-content'
      ]

      whereClause = []
      # build facet queries
      if facets and 'Everything' not in facets
        facetQueryList = []
        for facet in facets
          return callback new KodingError "Unknown facet: " + facets.join() if facet not in neo4jFacets
          facetQueryList.push("content.name='#{facet}'")
        whereClause.push("(" + facetQueryList.join(' OR ') + ")")
      # add timestamp

      if to
        timestamp = Math.floor(to / 1000)
        whereClause.push "content.`meta.createdAtEpoch` < #{timestamp}"

      if whereClause.length > 0
        query.push 'WHERE', whereClause.join(' AND ')

      # add return statement
      query.push "return distinct content"

      if options.sort.likesCount?
        query.push "order by coalesce(content.`meta.likes`?, 0) DESC"
      else if options.sort.repliesCount?
        query.push "order by coalesce(content.repliesCount?, 0) DESC"
      else
        query.push "order by content.`meta.createdAtEpoch` DESC"

      # add limit option
      query.push "LIMIT #{limit}"

      query = query.join('\n')

      graph = new Graph({config:KONFIG['neo4j']})
      options.returnAsBongoObjects = true
      graph.runQuery(query, options, callback)


  @fetchFolloweeContents: secure (client, options, callback)->
    @getCurrentGroup client, (err, group)=>
      if err then return callback err
      {Activity} = require "../graph"
      {facets, to, limit} = options
      requestOptions =
        userId : client.connection.delegate.getId()
        group :
          groupName : group.slug
          groupId : group._id
        limit : 5 #limit #bandage for now
        withExempt: options.withExempt
        facet : [facets]
        to : to
        client : client

      Activity.fetchFolloweeContents requestOptions, callback

  markAsRead: secure ({connection:{delegate}}, callback)->
    @update
      $addToSet: readBy: delegate.getId()
    , callback

  @checkIfLikedBefore: secure ({connection}, idsToCheck, callback)->
    {delegate} = connection
    if not delegate
      callback null, no
    else
      Relationship.some
        sourceId: {$in: idsToCheck}
        targetId: delegate.getId()
        as: 'like'
      , {}, (err, likedRels)=>
        likedIds = []
        for likedRel in likedRels
          likedIds.push likedRel.sourceId

        callback err, likedIds

  notifyCache = (event, contents)->
    routingKey = contents.group or 'koding'
    @emit 'cacheWorker', {routingKey, event, contents}

  @on 'ActivityIsCreated', notifyCache.bind this, 'ActivityIsCreated'
  @on 'PostIsUpdated',     notifyCache.bind this, 'PostIsUpdated'
  @on 'PostIsDeleted',     notifyCache.bind this, 'PostIsDeleted'
  @on 'BucketIsUpdated',   notifyCache.bind this, 'BucketIsUpdated'
  @on 'UserMarkedAsTroll', notifyCache.bind this, 'UserMarkedAsTroll'

  @fetchPublicActivityFeed = secure (client, options, callback)->
    @getCurrentGroup client, (err, group) =>
      if err then return callback err

      to = options.to
      to = if to then parseInt(to, 10) else (new Date).getTime()
      to = Math.floor(to/1000)  # unix vs js timestamp diff.

      neo4jConfig = KONFIG.neo4j
      requestOptions =
        client    : client
        startDate : to
        neo4j     : neo4jConfig
        withExempt: options.withExempt
        group     :
          groupName : group.slug
          groupId   : group._id
          facets    : options.facets

      FetchAllActivityParallel = require './../graph/fetch'
      fetch = new FetchAllActivityParallel requestOptions
      fetch.get (results)->
        callback null, results


