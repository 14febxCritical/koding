jraphical = require 'jraphical'

module.exports = class JComment extends jraphical.Reply
  
  {ObjectId,ObjectRef,dash,daisy,secure} = require 'bongo'
  {Relationship}  = require 'jraphical'
  
  @trait __dirname, '../../../traits/likeable'

  @share()

  @set
    sharedMethods  :
      instance     : ['delete','like','fetchLikedByes','checkIfLikedBefore']
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
        targetType : 'JAccount'
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
                callback new KodingError 'Access denied!'
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
