{Model} = require 'bongo'

module.exports = class JVM extends Model

  {permit} = require './group/permissionset'

  KodingError = require '../error'

  @share()

  @trait __dirname, '../traits/protected'

  @bound = require 'koding-bound'

  @set
    softDelete          : yes
    permissions         :
      'sudoer'          : []
      'create vms'      : ['member','moderator']
      'list all vms'    : ['member','moderator']
      'list default vm' : ['member','moderator']
    sharedMethods       :
      static            : ['fetchVmsByContext','calculateUsage']#,'create']
      instance          : []
    schema              :
      ip                :
        type            : String
        default         : -> null
      ldapPassword      :
        type            : String
        default         : -> null
      name              : String
      users             : Array
      groups            : Array
      usage             : # TODO: usage seems like the wrong term for this.
        cpu             :
          type          : Number
          default       : 1
        ram             :
          type          : Number
          default       : 0.25
        disk            :
          type          : Number
          default       : 0.5
      isEnabled         :
        type            : Boolean
        default         : yes
      shouldDelete      :
        type            : Boolean
        default         : no

  # TODO: this needs to be rethought in terms of bundles, as per the
  # discussion between Devrim, Chris T. and Badahir  C.T.
  # @createVm = (target, groupSlug, limit, callback)->
  #   unless 0 < limit.getValue()
  #     callback new KodingError 'Quota exceeded'
  #   else
  #     target.fetchUser (err, user)->
  #       return callback err  if err
  #       { usage } = limit
  #       vm = new JVM {
  #         name: "#{user.username}#{unless usage then '' else "~#{usage}"}"
  #         users: [{ id: user.getId(),  sudo: yes }]
  #       }
  #       vm.save (err)->
  #         return callback err  if err
  #         limit.update {$inc: usage: 1}, (err)->
  #           return callback err  if err
  #           callback null, vm

  # @create = permit 'create vms',
  #   success: (client, callback) ->

  # @initializeVmLimits =(target, callback)->
  #   JLimit = require './limit'
  #   limit = new JLimit { quota: 5 }
  #   limit.save (err)->
  #     return callback err  if err
  #     target.addLimit limit, 'vm', (err)->
  #       callback err ? null, unless err then limit

  @getUsageTemplate = -> { cpu: 0, ram: 0, disk: 0 }

  @calculateUsage = (account, groupSlug, callback)->
    nickname =
      if 'string' is typeof account then account
      else account.profile.nickname

    @all { name: ///$#{groupSlug}~#{nickname}~/// }, (err, vms) =>
      return callback err  if err?
      callback null, vms
        .map((vm) -> vm.usage)
        .reduce (acc, usage) ->
          for own field, val of usage
            acc[field] += val
            return acc
        , @getUsageTemplate()


  @calculateUsage$ = permit 'list all vms',
    success: (client, groupSlug, callback)->
      {delegate} = client.connection
      @calculateUsage delegate, groupSlug, callback

  @fetchVmsByContext = permit 'list all vms',
    success: (client, options, callback) ->
      [callback, options] = [options, callback]  unless callback

      options ?= {}
      options.limit = Math.min options.limit ? 10, 10

      JGroup = require './group'

      {context, connection:{delegate}} = client

      slug = context.group ? 'koding'

      delegate.fetchUser (err, user) ->
        return callback err  if err

        JGroup.one {slug}, (err, group) ->
          return callback err  if err

          selector =
            groups  : { $elemMatch: id: group.getId() }
            users   : { $elemMatch: id: user.getId() }

          JVM.someData selector, { name: 1 }, options, (err, cursor)->
            return callback err  if err

            cursor.toArray (err, arr)->
              return callback err  if err
              callback null, arr.map (vm)-> vm.name

    # TODO: let's implement something like this:
    # failure: (client, callback) ->
    #   @fetchDefaultVmByContext client, (err, vm)->
    #     return callback err  if err
    #     callback null, [vm]


  do ->

    handleError = (err)-> console.error err  if err

    JGroup  = require './group'
    JUser   = require './user'

    addVm = ({ target, user, name, sudo, groups })->
      vm = new JVM {
        name: name
        users: [
          { id: user.getId(), sudo: yes }
        ]
        groups: groups ? []
      }
      vm.save (err)-> target.addVm vm, handleError

    wrapGroup =(group)-> [ { id: group.getId() } ]

    uidFactory = (require 'koding-counter') {
      db          : JVM.getClient()
      counterName : 'uid'
      offset      : 1e6
    }

    uidFactory.reset (err, lastId)->
      console.log "UID counter is reset: %s", lastId

    JUser.on 'UserCreated', (user)->
      uidFactory.next (err, uid)->
        if err then handleError err
        else user.update { $set: { uid } }, handleError

    JGroup.on 'GroupCreated', ({group, creator})->
      creator.fetchUser (err, user)->
        if err then handleError err
        else
          addVm {
            user
            target  : group
            sudo    : yes
            name    : group.slug
            groups  : wrapGroup group
          }

    JGroup.on 'GroupDestroyed', (group)->
      group.fetchVms (err, vms)->
        if err then handleError err
        else vms.forEach (vm)-> vm.remove handleError

    JGroup.on 'MemberAdded', ({group, member})->
      member.fetchUser (err, user)->
        if err then handleError err
        else if group.slug is 'koding'
          # TODO: this special case for koding should be generalized for any group.
          addVm {
            user
            target  : member
            sudo    : yes
            name    : member.profile.nickname
          }
        else
          member.checkPermission group, 'sudoer', (err, hasPermission)->
            if err then handleError err
            else
              group.fetchVms (err, vms)->
                if err then handleError err
                else vms.forEach (vm)->
                  vm.update {
                    $addToSet: users: { id: user.getId(), sudo: hasPermission }
                  }, handleError

    JGroup.on 'MemberRemoved', ({group, member})->
      member.fetchUser (err, user)->
        if err then handleError err
        else if group.slug is 'koding'
          member.fetchVms (err, vms)->
            if err then handleError err
            else vms.forEach (vm)->
              vm.update {
                $set: { isEnabled: no, shouldDelete: yes }
              }, handleError
        else
          # group.fetchVms (err, vms)->
          #   if err then handleError err
          #   else vms.forEach (vm)->
          #     JVM.update {_id: vm.getId()}, { $pull: id: user.getId() }, handleError
          # TODO: the below is more efficient and a little less strictly correct than the above:
          JVM.update { groups: group.getId() }, { $pull: id: user.getId() }, handleError

    JGroup.on 'MemberRolesChanged', ({group, member})->
      return  if group.slug 'koding'  # TODO: remove this special case
      member.fetchUser (err, user)->
        if err then handleError err
        else
          member.checkPermission group, 'sudoer', (err, hasPermission)->
            if err then handleError err
            else if hasPermission
              member.fetchVms (err, vms)->
                if err then handleError err
                else
                  vms.forEach (vm)->
                    vm.update {
                      $set: users: vm.users.map (userRecord)->
                        isMatch = userRecord.id.equals user.getId()
                        return userRecord  unless isMatch
                        return { id, sudo: hasPermission }
                    }, handleError
