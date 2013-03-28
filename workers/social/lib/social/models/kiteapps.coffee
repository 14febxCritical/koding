jraphical = require 'jraphical'

module.exports = class JKiteApp extends jraphical.Module

  {Relationship} = jraphical

  {secure} = require 'bongo'

  @share()

  @set
    permissions: [
      'read kiteapps'
      'create kiteapps'
      'edit kiteapps'
      'delete kiteapps'
      'delete own kiteapps'
    ]  
    sharedMethods   :
      instance      : [
          'delete'
        ]
      static        : [
          'create', 'get', 'inc'
        ]
    schema          :
      username      :
        type        : String
        required    : yes
      methodName    :
        type        : String
        required    : yes
      kiteName      :
        type        : String
        required    : yes        
      count         :
        type        : Number
        required    : no
    
  @create = (data, callback)->
    data.count = 1
    kiteApp = new JKiteApp data
    kiteApp.save (err)->
      if err
        callback err
      else
        callback null, kiteApp

  @get = secure (data, callback)->

    @one {
      appKey     : data.appKey
    }, (err, appData)=>
      if err
        callback err
      else
        callback null, appData

  @inc = (data, callback)->

    @get data , (err, appData)=>
      if err
        callback err
      else
        if appData instanceof JKiteApp

          appData.update {$inc: 'count': 1} , (err) ->  
          callback null, appData        
        else 
          @create data, callback

  delete: secure ({connection:{delegate}}, callback)->
    @remove callback
