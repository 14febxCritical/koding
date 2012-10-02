module.exports = class Likeable

  {ObjectRef,daisy,secure} = require 'bongo'
  {Relationship} = require 'jraphical'

  checkIfLikedBefore: secure ({connection}, callback)->
    {delegate} = connection
    {constructor} = @
    Relationship.one
      sourceId: @getId()
      targetId: delegate.getId()
      as: 'like'
    , (err, likedBy)=>
      if likedBy
        callback null, yes
      else
        callback err, no

  like: secure ({connection}, callback)->
    JAccount  = require '../models/account'

    {delegate} = connection
    {constructor} = @
    unless delegate instanceof JAccount
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
                delegate.update ($inc: 'counts.likes': 1), (err)->
                  console.log err if err
                @fetchActivityId? (err, id)->
                  CActivity = require '../models/activity'
                  CActivity.update {_id: id}, {
                    $set: 'sorts.likesCount': count
                  }, ->
                @fetchOrigin? (err, origin)=>
                  if err then log "Couldn't fetch the origin"
                  else @emit 'LikeIsAdded', {
                    origin
                    subject       : ObjectRef(@).data
                    actorType     : 'liker'
                    actionType    : 'like'
                    liker         : ObjectRef(delegate).data
                    likesCount    : count
                    relationship  : docs[0]
                  }
          else
            @removeLikedBy delegate, respondWithCount: yes, (err, count)=>
              if err
                callback err
                console.log err
              else
                @update ($set: 'meta.likes': count), callback
                delegate.update ($inc: 'counts.likes': -1), (err)->
                  console.log err if err
