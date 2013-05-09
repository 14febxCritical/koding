
jraphical = require 'jraphical'
CActivity = require './activity'
JAccount  = require './account'
KodingError = require '../error'

module.exports = class JKodingKey extends jraphical.Module

  {Relationship} = jraphical

  {Base, secure, race} = require 'bongo'

  @share()

  @set
    softDelete        : yes
    sharedMethods     :
      static          : ['create', 'fetchAll', 'fetchByKey', 'fetchByUserKey']
    indexes           :
      key             : ['unique']
    schema            :
      key             : String
      hostname        : String
      owner           : String

  @create = secure (client, data, callback)->
    {delegate} = client.connection
    key = new JKodingKey
      key   : data.key
      owner : delegate._id
    key.save (err)->
      if err
        callback err
      else
        callback null, key

  @fetchAll = secure ({connection:{delegate}}, options, callback)->
    JKodingKey.all
      owner : delegate._id
    , (err, keys)->
      callback err, keys

  @fetchByKey = secure ({connection:{delegate}}, options, callback)->
    JKodingKey.all
      owner : delegate._id
      key   : options.key
    , (err, keys)->
      callback err, keys

  @fetchByUserKey = (options, callback)->
    JAccount.one
      'profile.nickname': options.username
    , (err, account)->
      if err then callback err
      else if not account
        callback null, null
      else
        JKodingKey.one
          key   : options.key
          owner : account._id
        , (err, key)->
          callback err, key
