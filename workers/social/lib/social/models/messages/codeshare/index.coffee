{Attachment} = require 'jraphical'

class JCodeShareAttachment extends Attachment
  @setSchema
    description : String
    content     : String
    syntax      : String

JPost = require '../post'

module.exports = class JCodeShare extends JPost

  {secure} = require 'bongo'

  {log} = console
  @share()

  @getActivityType =-> require './codeshareactivity'

  @getAuthorType =-> require '../../account'

  @set
    sharedMethods : JPost.sharedMethods
    schema        : JPost.schema
    # TODO: copying and pasting this for now...  We need an abstract interface "commentable" or something like that)
    relationships : JPost.relationships

  @create = secure (client, data, callback)->
    log "Creating from data",data
    codeShare=
      meta        : data.meta
      title       : data.title
      body        : data.body

      CodeShareItems : data.CodeShareItems or {}
      CodeShareOptions : data.CodeShareOptions or {}

    JPost.create.call @, client, codeShare, callback

  modify: secure (client, data, callback)->
    codeShare =
      meta        : data.meta
      title       : data.title
      body        : data.body

      CodeShareItems : data.CodeShareItems or {}
      CodeShareOptions : data.CodeShareOptions or {}

    JPost::modify.call @, client, codeShare, callback

  reply: secure (client, comment, callback)->
    JPost::reply.call @, client, JComment, comment, callback
