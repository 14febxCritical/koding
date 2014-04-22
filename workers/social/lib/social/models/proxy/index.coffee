jraphical   = require "jraphical"
KodingError = require "../../error"

module.exports = class JProxyFilter extends jraphical.Module

  {secure, ObjectId, signature} = require "bongo"

  @trait __dirname, "../../traits/protected"

  @share()

  @set
    sharedEvents      :
      static          : []
      instance        : []
    schema            :
      name            :
        type          : String
        required      : yes
      enabled         : Boolean
        defaultValue  : yes
      rules           : Array
      owner           : ObjectId
      createdAt       :
        type          : Date
        default       : -> new Date
      modifiedAt      :
        type          : Date
        default       : -> new Date
    sharedMethods     :
      static          :
        create        : (signature Object, Function)
        fetch         : (signature Function)

  @create: secure (client, data, callback = noop) ->
    {delegate}    = client.connection
    {name, rules} = data
    ruleTypes     = [ "ip", "country", "request.minute", "request.second" ]
    actionTypes   = [ "allow", "block", "securepage" ]

    unless name and rules?.length
      return callback new KodingError "Missing arguments", null

    for rule in rules
      {enabled, type, match, action} = rule
      hasAllFields       = enabled and type and match and action
      hasValidRuleType   = ruleTypes.indexOf(type)     isnt -1
      hasValidActionType = actionTypes.indexOf(action) isnt -1

      unless hasAllFields and hasValidRuleType and hasValidActionType
        hasInvalidRule = yes

    if hasInvalidRule
      return callback new KodingError "One or more rules are invalid", null

    data.owner = delegate.getId()
    filter     = new JProxyFilter data

    filter.save (err) ->
      return callback err, null  if err
      callback null, filter

  @fetch: secure (client, callback = noop) ->
    query = owner: client.connection.delegate.getId()

    JProxyFilter.some query, {}, (err, filters) ->
      return callback err, null  if err
      callback null, filters
