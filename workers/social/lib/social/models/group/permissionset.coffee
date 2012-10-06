{Model, secure, dash} = require 'bongo'
{Module} = require 'jraphical'

class JPermission extends Model
  @setSchema
    module  : String
    title   : String
    body    : String
    roles   : [String]

module.exports = class JPermissionSet extends Module

  KodingError = require '../../error'

  @checkPermission =(delegate, permission, target, callback)->
    target.fetchAuthorityChain (err, chain)->
      if err
        callback err
      else
        permissions = []
        queue = chain.map (group)->->
          delegate.fetchRoles group, (err, roles)->
            if err then queue.fin(err)
            else if roles.length
              if 'admin' in roles
                permissions.push yes
                queue.fin()
              else if ('moderator' in roles or 'member' in roles) or \
                      group.privacy is 'public' and 'guest' in roles
                group.fetchPermissionSet (err, permissionSet)->
                  if err then queue.fin(err)
                  else
                    matchingPermissions = [].filter.call(
                      permissionSet.permissions
                      (savedPermission)->
                        savedPermission.module is target.constructor.name and\
                        savedPermission.role in roles and\
                        permission in savedPermission.permissions
                    )
                    permissions.push !!matchingPermissions.length
                    queue.fin()
              else
                permissions.push no
                queue.fin()
            else permissions.push no
        dash queue, ->
          hasPermission = yes in permissions
          callback null, hasPermission

  @permit =(permission, promise)->
    secure (client, rest...)->
      if 'function' is typeof rest[rest.length-1]
        [rest..., callback] = rest
      else
        callback =->
      success =
        if 'function' is typeof promise then promise.bind(@)
        else promise.success.bind(@)
      failure = promise.failure?.bind(@) ? (args...)-> callback args...
      {delegate} = client.connection
      JPermissionSet.checkPermission(
        delegate
        permission
        @, (err, hasPermission)->
          if err
            failure err
          else if hasPermission
            success.apply @, [client].concat rest
          else
            failure new KodingError 'Access denied!'
      )

  @set
    schema        :
      permissions : [JPermission]

