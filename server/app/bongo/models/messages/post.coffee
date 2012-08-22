class JPost extends jraphical.Message

  @mixin Followable
  @::mixin Followable::
  @::mixin Taggable::
  @::mixin Notifying::
  @mixin Flaggable
  @::mixin Flaggable::

  {Base,ObjectRef,secure,dash,daisy} = bongo
  {Relationship} = jraphical

  {log} = console

  schema = _.extend {}, jraphical.Message.schema, {
    isLowQuality  : Boolean
    counts        :
      followers   :
        type      : Number
        default   : 0
      following   :
        type      : Number
        default   : 0
  }

  # TODO: these relationships may not be abstract enough to belong to JPost.
  @set
    emitFollowingActivities: yes
    taggedContentRole : 'post'
    tagRole           : 'tag'
    sharedMethods     :
      static          : ['create','on','one']
      instance        : [
        'on','reply','restComments','commentsByRange'
        'like','fetchLikedByes','mark','unmark','fetchTags'
        'delete','modify','fetchRelativeComments'
      ]
    schema            : schema
    relationships     :
      comment         : JComment
      participant     :
        targetType    : JAccount
        as            : ['author','commenter']
      likedBy         :
        targetType    : JAccount
        as            : 'like'
      repliesActivity :
        targetType    : CRepliesActivity
        as            : 'repliesActivity'
      tag             :
        targetType    : JTag
        as            : 'tag'
      follower        :
        as            : 'follower'
        targetType    : JAccount

  @getAuthorType =-> JAccount

  @getActivityType =-> CActivity

  @getFlagRole =-> ['sender', 'recipient']

  createKodingError =(err)->
    kodingErr = new KodingError(err.message)
    for own prop of err
      kodingErr[prop] = err[prop]
    kodingErr

  @create = secure (client, data, callback)->
    constructor = @
    {connection:{delegate}} = client
    unless delegate instanceof constructor.getAuthorType() # TODO: rethink/improve
      callback new Error 'Access denied!'
    else
      if data?.meta?.tags
        {tags} = data.meta
        delete data.meta.tags
      status = new constructor data
      # TODO: emit an event, and move this (maybe)
      activity = new (constructor.getActivityType())
      if delegate.checkFlag 'exempt'
        status.isLowQuality = yes
        activity.isLowQuality = yes
      activity.originId = delegate.getId()
      activity.originType = delegate.constructor.name
      teaser = null
      daisy queue = [
        ->
          status
            .sign(delegate)
            .save (err)->
              if err
                callback err
              else queue.next()
        ->
          delegate.addContent status, (err)-> queue.next(err)
        ->
          activity.save (err)->
            if err
              callback createKodingError err
            else queue.next()
        ->
          activity.addSubject status, (err)->
            if err
              callback createKodingError err
            else queue.next()
        ->
          delegate.addContent activity, (err)-> queue.next(err)
        ->
          tags or= []
          status.addTags client, tags, (err)->
            if err
              log err
              callback createKodingError err
            else
              queue.next()
        ->
          status.fetchTeaser (err, teaser_)=>
            if err
              callback createKodingError err
            else
              teaser = teaser_
              queue.next()
        ->
          activity.update
            $set:
              snapshot: JSON.stringify(teaser)
            $addToSet:
              snapshotIds: status.getId()
          , ->
            callback null, teaser
            queue.next()
        ->
          status.addParticipant delegate, 'author'
      ]

  constructor:->
    super
    @notifyOriginWhen 'ReplyIsAdded', 'LikeIsAdded'
    @notifyFollowersWhen 'ReplyIsAdded'

  fetchOrigin: (callback)->
    originType = @getAt 'originType'
    originId   = @getAt 'originId'
    if Base.constructors[originType]?
      Base.constructors[originType].one {_id: originId}, callback
    else
      callback null

  modify: secure (client, formData, callback)->
    {delegate} = client.connection
    if delegate.getId().equals @originId
      {tags} = formData.meta if formData.meta?
      delete formData.meta
      daisy queue = [
        =>
          tags or= []
          @addTags client, tags, (err)=>
            if err
              callback err
            else
              queue.next()
        =>
          @update $set: formData, callback
      ]
    else
      callback new KodingError "Access denied"

  delete: secure ({connection:{delegate}}, callback)->
    originId = @getAt 'originId'
    unless delegate.getId().equals originId
      callback new KodingError 'Access denied!'
    else
      id = @getId()
      {getDeleteHelper} = Relationship
      queue = [
        getDeleteHelper {
          targetId    : id
          sourceName  : /Activity$/
        }, 'source', -> queue.fin()
        getDeleteHelper {
          sourceId    : id
          sourceName  : 'JComment'
        }, 'target', -> queue.fin()
        ->
          Relationship.remove {
            targetId  : id
            as        : 'post'
          }, -> queue.fin()
        => @remove -> queue.fin()
      ]
      dash queue, =>
        @emit 'PostIsDeleted', 1
        callback null

  fetchActivityId:(callback)->
    Relationship.one {
      targetId    : @getId()
      sourceName  : /Activity$/
    }, (err, rel)->
      if err
        callback err
      else unless rel
        callback new KodingError 'No activity found'
      else
        callback null, rel.getAt 'sourceId'

  fetchActivity:(callback)->
    @fetchActivityId (err, id)->
      if err
        callback err
      else
        CActivity.one _id: id, callback

  flushSnapshot:(removedSnapshotIds, callback)->
    removedSnapshotIds = [removedSnapshotIds] unless Array.isArray removedSnapshotIds
    teaser = null
    activityId = null
    queue = [
      =>
        @fetchActivityId (err, activityId_)->
          activityId = activityId_
          queue.next()
      =>
        @fetchTeaser (err, teaser_)=>
          if err
            callback createKodingError err
          else
            teaser = teaser_
            queue.next()
      ->
        CActivity.update _id: activityId, {
          $set:
            snapshot              : JSON.stringify teaser
            'sorts.repliesCount'  : teaser.repliesCount
          $pullAll:
            snapshotIds: removedSnapshotIds
        }, -> queue.next()
      callback
    ]
    daisy queue

  removeReply:(rel, callback)->
    id = @getId()
    teaser = null
    activityId = null
    repliesCount = @getAt 'repliesCount'
    queue = [
      ->
        rel.update $set: 'data.deletedAt': new Date, -> queue.next()
      =>
        @update $inc: repliesCount: -1, -> queue.next()
      =>
        @flushSnapshot rel.getAt('targetId'), -> queue.next()
      callback
    ]
    daisy queue

  like: secure ({connection}, callback)->
    {delegate} = connection
    {constructor} = @
    unless delegate instanceof constructor.getAuthorType()
      callback new Error 'Only instances of JAccount can like things.'
    else
      Relationship.one
        sourceId: @getId()
        targetId: delegate.getId()
        as: 'like'
      , (err, likedBy)=>
        if err
          callback err
        else
          unless likedBy
            @addLikedBy delegate, respondWithCount: yes, (err, docs, count)=>
              if err
                callback err
              else
                @update ($set: 'meta.likes': count), callback
                @fetchActivityId (err, id)->
                  CActivity.update {_id: id}, {
                    $set: 'sorts.likesCount': count
                  }, log
                @fetchOrigin (err, origin)=>
                  if err then log "Couldn't fetch the origin"
                  else @emit 'LikeIsAdded', {
                    origin
                    subject       : ObjectRef(@).data
                    actorType     : 'liker'
                    actionType    : 'like'
                    liker    		  : ObjectRef(delegate).data
                    likesCount	  : count
                    relationship  : docs[0]
                  }
          else
            callback new KodingError 'You already like this.'
            ###
            @removeLikedBy delegate, respondWithCount: yes, (err, docs, count)=>
              if err
                callback err
                console.log err
              else
                count ?= 1
                @update ($set: 'meta.likes': count), callback
            ###

  reply: secure (client, replyType, comment, callback)->
    {delegate} = client.connection
    unless delegate instanceof JAccount
      callback new Error 'Log in required!'
    else
      comment = new replyType body: comment
      exempt = delegate.checkFlag('exempt')
      if exempt
        comment.isLowQuality = yes
      comment
        .sign(delegate)
        .save (err)=>
          if err
            callback err
          else
            delegate.addContent comment, (err)-> console.log 'error adding content', err
            @addComment comment,
              flags:
                isLowQuality    : exempt
            , (err, docs)=>
              if err
                callback err
              else
                if exempt
                  callback null, comment
                else
                  Relationship.count {
                    sourceId                    : @getId()
                    as                          : 'reply'
                    'data.flags.isLowQuality'   : $ne: yes
                  }, (err, count)=>
                    if err
                      callback err
                    else
                      @update $set: repliesCount: count, (err)=>
                        if err
                          callback err
                        else
                          callback null, comment
                          @fetchActivityId (err, id)->
                            CActivity.update {_id: id}, {
                              $set: 'sorts.repliesCount': count
                            }, log
                          @fetchOrigin (err, origin)=>
                            if err
                              console.log "Couldn't fetch the origin"
                            else
                              unless exempt
                                @emit 'ReplyIsAdded', {
                                  origin
                                  subject       : ObjectRef(@).data
                                  actorType     : 'replier'
                                  actionType    : 'reply'
                                  replier 		  : ObjectRef(delegate).data
                                  reply   		  : ObjectRef(comment).data
                                  repliesCount	: count
                                  relationship  : docs[0]
                                }
                              @follow client, emitActivity: no, (err)->
                              @addParticipant delegate, 'commenter', (err)-> #TODO: what should we do with this error?

  # TODO: the following is not well-factored.  It is not abstract enough to belong to "Post".
  # for the sake of expedience, I'll leave it as-is for the time being.
  fetchTeaser:(callback)->
    @beginGraphlet()
      .edges
        query         :
          targetName  : 'JComment'
          as          : 'reply'
          'data.deletedAt':
            $exists   : no
          'data.flags.isLowQuality':
            $ne       : yes
        limit         : 3
        sort          :
          timestamp   : -1
      .reverse()
      .and()
      .edges
        query         :
          targetName  : 'JTag'
          as          : 'tag'
        limit         : 5
      .nodes()
    .endGraphlet()
    .fetchRoot callback

  fetchRelativeComments:({limit, before, after}, callback)->
    limit ?= 10
    if before? and after?
      callback new KodingError "Don't use before and after together."
    selector = timestamp:
      if before? then  $lt: before
      else if after? then $gt: after
    selector['data.flags.isLowQuality'] = $ne: yes
    options = {limit, sort: timestamp: 1}
    @fetchComments selector, options, callback

  commentsByRange:(options, callback)->
    [callback, options] = [options, callback] unless callback
    {from, to} = options
    from or= 0
    if from > 1e6
      selector = timestamp:
        $gte: new Date from
        $lte: to or new Date
      queryOptions = {}
    else
      to or= Math.max()
      selector = {}
      queryOptions = skip: from
      if to
        queryOptions.limit = to - from
    selector['data.flags.isLowQuality'] = $ne: yes
    queryOptions.sort = timestamp: -1
    console.log queryOptions
    @fetchComments selector, queryOptions, callback

  restComments:(skipCount, callback)->
    [callback, skipCount] = [skipCount, callback] unless callback
    skipCount ?= 3
    @fetchComments {
      'data.flags.isLowQuality': $ne: yes
    },
      skip: skipCount
      sort:
        timestamp: 1
    , (err, comments)->
      if err
        callback err
      else
        # comments.reverse()
        callback null, comments

  fetchEntireMessage:(callback)->
    @beginGraphlet()
      .edges
        query         :
          targetName  :'JComment'
        sort          :
          timestamp   : 1
      .nodes()
    .endGraphlet()
    .fetchRoot callback

  save:->
    delete @data.replies #TODO: this hack should not be necessary...  but it is for some reason.
    # in any case, it should be resolved permanently once we implement Model#prune
    super
