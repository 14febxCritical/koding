bongo = require './bongo'

handleError = (err, callback) ->
  console.error err
  return callback err


fetchGroupName = (req, callback)->
  [name, section] = req.params
  {JName} = bongo.models

  groupName = ""
  # this means it is not a group or profile feed
  # and it means it is koding group
  # it is like Activity -- Develop

  if not name or name[0].toUpperCase() is name[0]
    return callback null, "koding"
  else
    JName.fetchModels "#{name}/#{section}", (err, models)->
      return callback if err
      return callback new Error "JName is not found #{name}/#{section}" if not models and model.length < 1

      model = models.first
      modelName = model.bongo_.constructorName
      if modelName is 'JGroup'
        groupName = model.slug
      else
        groupName = "koding"

      callback null, groupName

fetchAccount = (username, callback)->
  bongo.models.JAccount.one {"profile.nickname" : username }, callback


generateFakeClient = (req, res, callback)->

  fakeClient    =
    context     :
      group     : 'koding'
      user      : 'guest-1'
    connection  :
      delegate  : null
      groupName : 'koding'

  {clientId} = req.cookies

  return callback null, fakeClient unless clientId?

  bongo.models.JSession.fetchSession clientId, (err, session)->
    return handleError err, callback if err
    return handleError new Error "Session is not set", callback unless session?

    fetchGroupName req, (err, groupName)->
      return handleError err, callback if err
      fetchAccount session.username, (err, account)->
        return handleError err, callback if err

        # set real client id if it is in the db
        fakeClient.sessionToken = session.clientId

        # set username into context
        fakeClient.context = {}
        fakeClient.context.group = groupName
        fakeClient.context.user  = session.username

        # create connection property
        fakeClient.connection = {}
        fakeClient.connection.delegate  = account
        fakeClient.connection.groupName = groupName

        return callback null, fakeClient

module.exports = { generateFakeClient }

