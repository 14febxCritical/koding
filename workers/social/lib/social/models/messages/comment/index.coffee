jraphical = require 'jraphical'
JAccount = require '../../account'

module.exports = class JComment extends jraphical.Reply

  {ObjectId,ObjectRef,dash,daisy,secure,signature} = require 'bongo'
  {Relationship}  = require 'jraphical'

  @trait __dirname, '../../../traits/likeable'
  @trait __dirname, '../../../traits/notifying'
  @trait __dirname, '../../../traits/grouprelated'

  @share()

  constructor:->
    super
    @notifyOriginWhen 'LikeIsAdded'

  @set
    sharedMethods  :
      static       :
        fetchRelated:
          (signature ObjectId, Function)
        one:
          (signature Object, Function)
      instance     :
        delete:
          (signature Function)
        like:
          (signature Function)
        fetchLikedByes: [
          (signature Function)
          (signature Object, Function)
          (signature Object, Object, Function)
        ]
        checkIfLikedBefore:
          (signature Function)
    sharedEvents  :
      instance    : [
        { name: 'updateInstance' }
        { name: 'RemovedFromCollection' }
      ]
      static    : [
        { name: 'updateInstance' }
        { name: 'RemovedFromCollection' }
      ]
    schema         :
      isLowQuality : Boolean
      body         :
        type       : String
        required   : yes
      originType   :
        type       : String
        required   : yes
      originId     :
        type       : ObjectId
        required   : yes
      deletedAt    : Date
      deletedBy    : ObjectRef
      meta         : require 'bongo/bundles/meta'
    relationships  :
      likedBy      :
        targetType : JAccount
        as         : 'like'

  delete: secure (client, callback)->
    {delegate} = client.connection
    {getDeleteHelper} = Relationship
    id = @getId()
    comment = @
    queue = [
      ->
        Relationship.one {
          targetId  : id
          as        : 'reply'
        }, (err, rel)->
          if err
            queue.fin err
          else
            rel.fetchSource (err, message)->
              if err
                queue.fin err
              else if delegate.can 'delete', comment
                message.removeReply rel, -> queue.fin()
              else
                callback new KodingError 'Access denied'
      =>
        deleter = ObjectRef(delegate)
        @update
          $unset      :
            body      : 1
          $set        :
            deletedAt : new Date
            deletedBy : deleter
        , -> queue.fin()
    ]
    dash queue, callback

  _flagIsLowQuality:(isLowQuality, inc, callback)->
    Relationship.one {
      targetId  : @getId()
      as        : 'reply'
    }, (err, rel)->
      if err then queue.fin err
      else
        rel.fetchSource (err, message)->
          if err then queue.fin err
          else
            repliesCount = message.getAt 'repliesCount'
            daisy queue = [
              ->
                rel.update $set: 'data.flags.isLowQuality': isLowQuality,
                  -> queue.next()
              ->
                message.update $inc: repliesCount: inc, -> queue.next()
              ->
                message.updateSnapshot -> queue.next()
              ->
                message.triggerCache()
                queue.next()
              callback
            ]

  flagIsLowQuality:(callback)->
    @_flagIsLowQuality yes, -1, callback

  unflagIsLowQuality:(callback)->
    @_flagIsLowQuality no, 1, callback
