{Model} = require 'bongo'
{Relationship, Module} = require 'jraphical'

module.exports = class JVM extends Module

  {permit} = require './group/permissionset'
  {secure, dash} = require 'bongo'
  {uniq}   = require 'underscore'

  {argv} = require 'optimist'

  KodingError = require '../error'

  JPaymentSubscription = require './payment/subscription'
  JPermissionSet       = require './group/permissionset'
  @share()

  @trait __dirname, '../traits/protected'

  @bound = require 'koding-bound'

  handleError = (err)-> console.error err  if err

  @set
    softDelete          : yes
    indexes             :
      hostnameAlias     : 'unique'
    permissions         :
      'sudoer'          : []
      'create vms'      : ['member','moderator']
      'delete vms'      : ['member','moderator']
    sharedEvents        :
      static            : [
        { name : "RemovedFromCollection" }
      ]
      instance          : [
        { name : "RemovedFromCollection" }
        { name : "control" }
      ]
    sharedMethods       :
      static            : [
                           'fetchVms','fetchVmsByContext', 'fetchVmInfo'
                           'fetchDomains', 'removeByHostname', 'someData'
                           'count', 'fetchDefaultVm', 'fetchVmRegion' #'calculateUsage'
                          ]
      instance          : []
    schema              :
      ip                :
        type            : String
        default         : -> null
      ldapPassword      :
        type            : String
        default         : -> null
      hostnameAlias     : String
      hostKite          :
        type            : String
        default         : -> null
      region            :
        type            : String
        enum            : ['unknown region'
                          [
                            'aws' # Amazon Web Services
                            'sj'  # San Jose
                            'vagrant'
                          ]]
        default         : if argv.c is 'vagrant' then 'vagrant' else 'sj'
      webHome           : String
      planOwner         : String
      planCode          : String
      vmType            :
        type            : String
        default         : 'user'
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
      diskSizeInMB      :
        type            : Number
        default         : 1200

  suspend: (callback)->
    @update { $set: { hostKite: '(banned)' } }, (err)=>
      return callback err if err
      @emit 'control', {
        routingKey: "control.suspendVM"
        @hostnameAlias
      }
      return callback null

  @createDomains = (account, domains, hostnameAlias)->

    updateRelationship = (domainObj)->
      Relationship.one
        targetName: "JDomain",
        targetId: domainObj._id,
        sourceName: "JAccount",
        sourceId: account._id,
        as: "owner"
      , (err, rel)->
        if err or not rel
          account.addDomain domainObj, (err)->
            console.log err  if err?

    JDomain = require './domain'
    domains.forEach (domain) ->
      domainObj = new JDomain
        domain        : domain
        hostnameAlias : [hostnameAlias]
        proxy         : { mode: 'vm' }
        regYears      : 0
        loadBalancer  : { persistance: 'disabled' }
      domainObj.save (err)->
        return console.log err  if err
        updateRelationship domainObj

  @fixUserDomains = permit 'change bundle',
    success: (client, callback)->

      unless client.context.group is "koding"
        return callback new KodingError "You are not Koding admin."

      JDomain = require './domain'
      JUser   = require './user'

      JVM.each {}, {}, (err, vm) =>
        return callback err  if err
        return callback null, null  unless vm
        {nickname, groupSlug, uid, type} = @parseAlias vm.hostnameAlias
        hostnameAliases = JVM.createAliases {
          nickname, type, uid, groupSlug
        }
        [vmUser] = vm.users.filter (u) -> u.owner is yes
        if vmUser?
          JUser.one { _id: vmUser.id }, (err, user) =>
            if not err and user
              user.fetchAccount 'koding', (err, account) =>
                console.log "WORKING ON VM FOR #{nickname} - #{hostnameAliases[0]}"
                if not err and account
                  @ensureDomainSettings {account, vm, type, nickname, groupSlug}
                  @createDomains account, hostnameAliases, hostnameAliases[0]

  @ensureDomainSettings = ({account, vm, type, nickname, groupSlug})->
    domain = 'kd.io'
    if type in ['user', 'expensed']
      requiredDomains = ["#{nickname}.#{groupSlug}.#{domain}"]
      if groupSlug is 'koding'
        requiredDomains.push "#{nickname}.#{domain}"
    else
      requiredDomains = ["#{groupSlug}.#{domain}", "shared.#{groupSlug}.#{domain}"]
    @createDomains account, requiredDomains, vm.hostnameAlias

  @createAliases = ({nickname, type, uid, groupSlug})->
    domain       = 'kd.io'
    aliases      = []
    if type in ['user', 'expensed']
      if uid is 0
        aliases.push "#{nickname}.#{groupSlug}.#{domain}"
      if groupSlug is 'koding'
        aliases.push "#{nickname}.#{domain}"  if uid is 0
        aliases.push "vm-#{uid}.#{nickname}.#{domain}"
      aliases.push "vm-#{uid}.#{nickname}.#{groupSlug}.#{domain}"

    else if type is 'group'
      if uid is 0
        aliases = ["#{groupSlug}.#{domain}"
                   "shared.#{groupSlug}.#{domain}"
                   "shared-0.#{groupSlug}.#{domain}"]
      else
        aliases = ["shared-#{uid}.#{groupSlug}.#{domain}"]

    return aliases.reverse()

  @parseAlias = (alias)->
    # group-vm alias
    if /^shared\-[0-9]+/.test alias
      result = alias.match /(.*)\.([a-z0-9\-]+)\.kd\.io$/
      if result
        [rest..., prefix, groupSlug] = result
        uid = parseInt(prefix.split(/-/)[1], 10)
        return {groupSlug, prefix, uid, type:'group', alias}
    # personal-vm alias
    else if /^vm\-[0-9]+/.test alias
      result = alias.match /(.*)\.([a-z0-9\-]+)\.([a-z0-9\-]+)\.kd\.io$/
      if result
        [rest..., prefix, nickname, groupSlug] = result
        uid = parseInt(prefix.split(/-/)[1], 10)
        return {groupSlug, prefix, nickname, uid, type:'user', alias}
    return null

  # TODO: this needs to be rethought in terms of bundles, as per the
  # discussion between Devrim, Chris T. and Badahir  C.T.
  @createVm = ({account, type, groupSlug, usage, planCode}, callback)->
    JGroup = require './group'
    JGroup.one {slug: groupSlug}, (err, group)=>
      return callback err  if err
      account.fetchUser (err, user)=>
        return callback err  if err

        # We are keeping this names just for counter
        planOwner   = "group_#{group._id}"
        counterName = "#{groupSlug}~"
        webHome     = groupSlug

        if type is 'user'
          planOwner   = "user_#{account._id}"
          counterName = "#{groupSlug}~#{user.username}~"
          webHome     = user.username
        else if type is 'expensed'
          planOwner   = "group_#{group._id}"
          counterName = "#{groupSlug}~#{user.username}~"
          webHome     = user.username

        nameFactory = (require 'koding-counter') {
          db     : JVM.getClient()
          offset : 0
          counterName
        }

        nameFactory.next (err, uid)=>
          return callback err  if err

          nickname = user.username
          hostnameAliases = JVM.createAliases {
            nickname, type, uid, groupSlug
          }
          users         = [{ id: user.getId(), sudo: yes, owner: yes }]
          groups        = [{ id: group.getId() }]
          hostnameAlias = hostnameAliases[0]

          vm = new JVM {
            hostnameAlias
            planOwner
            planCode
            webHome
            groups
            users
            usage
            vmType: type
          }

          vm.save (err) =>

            if err
              console.error err
              return console.warn "Failed to create VM for ", \
                                   {users, groups, hostnameAlias}

            JVM.createDomains account, hostnameAliases, hostnameAliases[0]

            group.addVm vm, (err)=>
              return callback err  if err
              JVM.ensureDomainSettings {account, vm, type, nickname, groupSlug}
              if type is 'group'
                @addVmUsers vm, group, ->
                  callback null, vm
              else
                callback null, vm

  @addVmUsers = (vm, group, callback)->
    group.fetchMembers (err, members)->
      return callback err  if err
      members.forEach (member)->
        member.fetchUser (err, user)->
          if err then callback err
          else
            member.checkPermission group, 'sudoer', (err, hasPermission)->
              if err then handleError err
              else
                vm.update {
                  $addToSet: users: { id: user.getId(), sudo: hasPermission }
                }, callback

  # @getUsageTemplate = -> { cpu: 0, ram: 0, disk: 0 }

  # @calculateUsage = (account, groupSlug, callback)->
  #   nickname =
  #     if 'string' is typeof account then account
  #     else account.profile.nickname

  #   @all { name: ///$#{groupSlug}~#{nickname}~/// }, (err, vms) =>
  #     return callback err  if err?
  #     callback null, vms
  #       .map((vm) -> vm.usage)
  #       .reduce (acc, usage) ->
  #         for own field, val of usage
  #           acc[field] += val
  #           return acc
  #       , @getUsageTemplate()

  # @calculateUsage$ = secure (client, groupSlug, callback)->
  #     {delegate} = client.connection
  #     @calculateUsage delegate, groupSlug, callback

  @fetchVmInfo = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection

    delegate.fetchUser (err, user) ->
      return callback err  if err

      JVM.one
        hostnameAlias : hostnameAlias
        users         : { $elemMatch: id: user.getId() }
      , (err, vm)->
        return callback err  if err
        return callback null, null  unless vm
        callback null,
          planCode         : vm.planCode
          planOwner        : vm.planOwner
          hostnameAlias    : vm.hostnameAlias
          underMaintenance : vm.hostKite is "(maintenance)"
          region           : vm.region or 'sj'

  @fetchVmRegion = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection
    JVM.one {hostnameAlias}, (err, vm)->
      return callback err  if err or not vm
      callback null, vm.region

  @fetchDefaultVm = secure (client, callback)->
    {delegate} = client.connection
    delegate.fetchUser (err, user) ->
      return callback err  if err
      JGroup = require './group'
      JGroup.one slug:'koding', (err, fetchedGroup)=>
        return callback err  if err
        JVM.one
          users    : { $elemMatch: id: user.getId() }
          groups   : { $elemMatch: id: fetchedGroup.getId() }
          planCode : 'free'
        , (err, vm)->
          return callback err  if err
          callback err, vm?.hostnameAlias

  @fetchAccountVmsBySelector = (account, selector, options, callback) ->
    [callback, options] = [options, callback]  unless callback

    options ?= {}
    # options.limit = Math.min options.limit ? 10, 10

    account.fetchUser (err, user) ->
      return callback err  if err

      selector.users = $elemMatch: id: user.getId()

      JVM.someData selector, { hostnameAlias: 1 }, options, (err, cursor)->
        return callback err  if err

        cursor.toArray (err, arr)->
          return callback err  if err
          callback null, arr.map (vm)-> vm.hostnameAlias

  @fetchVmsByContext = secure (client, options, callback) ->
    {connection:{delegate}, context:{group}} = client
    JGroup = require './group'

    slug = group ? if delegate.type is 'unregistered' then 'guests' else 'koding'

    JGroup.one {slug}, (err, fetchedGroup) =>
      return callback err  if err

      selector = groups: { $elemMatch: id: fetchedGroup.getId() }
      @fetchAccountVmsBySelector delegate, selector, options, callback

  @fetchVms = secure (client, options, callback) ->
      {delegate} = client.connection
      @fetchAccountVmsBySelector delegate, {}, options, callback

    # TODO: let's implement something like this:
    # failure: (client, callback) ->
    #   @fetchDefaultVmByContext client, (err, vm)->
    #     return callback err  if err
    #     callback null, [vm]

  # Private static method to fetch domains
  @fetchDomains = (selector, callback)->
    JDomain = require './domain'
    JDomain.someData selector, {domain:1}, \
    (err, cursor)->
      return callback err, []  if err
      cursor.toArray (err, arr)->
        return callback err, []  if err
        callback null, arr.map (vm)-> vm.domain

  # Public(shared) static method to fetch domains
  # which points to given hostnameAlias
  @fetchDomains$ = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection

    delegate.fetchUser (err, user) ->
      return callback err  if err

      selector =
        hostnameAlias : hostnameAlias
        users         : { $elemMatch: id: user.getId() }

      JVM.one selector, {hostnameAlias:1}, (err, vm)->
        return callback err, []  if err or not vm
        JVM.fetchDomains {hostnameAlias: vm.hostnameAlias}, callback

  @removeRelatedDomains = (vm, callback=->)->
    vmInfo = @parseAlias vm.hostnameAlias
    return callback null  unless vmInfo

    # Create same aliases based on vm info
    aliasesToDelete = @createAliases vmInfo

    # If calculated uid is greater than 0 we also try to add
    # aliases which has uid 0
    if vmInfo.uid > 0
      vmInfo.uid = 0
      aliasesToDelete = uniq aliasesToDelete.concat @createAliases vmInfo

    selector =
      hostnameAlias : vm.hostnameAlias
      domain        : { $in : aliasesToDelete }

    JDomain = require './domain'
    JDomain.remove selector, (err)->
      callback err
      return console.error "Failed to delete domains:", err  if err

  remove: (callback)->
    JVM.removeRelatedDomains this
    super callback

  @deleteVM = (vm, callback)->
    if vm.planCode is 'free'
      vm.remove callback
    else
      JPaymentSubscription.fetchAllSubscriptions vm.planOwner,
        userCode : vm.planOwner
        planCode : vm.planCode
        $or      : [
          {status: 'active'}
          {status: 'canceled'}
        ]
      , (err, subs)->
        if err
          return callback new KodingError 'Unable to update subscription.'
        subs.forEach (sub)->
          if sub.status is 'canceled'
            vm.remove callback
          else if sub.quantity > 1
            sub.update sub.quantity - 1, (err, sub)->
              if err
                return callback new KodingError 'Unable to update subscription.'
              vm.remove callback
          else
            sub.terminate (err, newSub)->
              if err
                return callback new KodingError 'Unable to terminate payment'
              else
                vm.remove callback

  @removeByHostname = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection

    delegate.fetchUser (err, user)=>
      return callback err  if err

      selector =
        hostnameAlias : hostnameAlias
        users         : { $elemMatch: id: user.getId(), owner: yes }

      JVM.one selector, (err, vm)=>
        return callback err  if err
        return callback new KodingError 'No such VM'  unless vm

        if vm.planOwner.indexOf("user_") > -1
          @deleteVM vm, callback
        else
          groupID = vm.planOwner.split('_')[1]

          JGroup = require './group'
          JGroup.one {_id: groupID}, (err, group)=>
            return callback err  if err
            JPermissionSet.checkPermission client, "delete vms", group,
            (err, hasPermission)=>
              return callback err  if err
              if hasPermission
                @deleteVM vm, callback


  do ->

    JAccount  = require './account'
    JGroup    = require './group'
    JUser     = require './user'

    addVm = ({ account, target, user, sudo, groups, groupSlug
               type, planCode, planOwner, webHome })->

      uid = 0
      hostnameAliases = JVM.createAliases {
        nickname : user.username
        type, uid, groupSlug
      }

      users = [
        { id: user.getId(), sudo: yes, owner: yes }
      ]

      [hostnameAlias]  = hostnameAliases
      groups          ?= []

      vm = new JVM {
        hostnameAlias
        planOwner
        planCode
        webHome
        groups
        users
        vmType: type
      }

      vm.save (err)->

        handleError err
        if err
          return console.warn "Failed to create VM for ", \
                               {users, groups, hostnameAlias}

        JVM.createDomains account, hostnameAliases, hostnameAlias
        target.addVm vm, handleError

    wrapGroup =(group)-> [ { id: group.getId() } ]

    uidFactory = null

    require('bongo').Model.on 'dbClientReady', ->
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

    JUser.on "UserBlocked", (user)->
      selector =
        'users.id'    : user.getId()
        'users.owner' : yes

      JVM.some selector, {}, (err, vms)->
        return console.error err  if err
        queue = vms.map (vm)->->
          # shutdown all vms that user has
          vm.suspend -> queue.fin()
        if queue.length > 0
          dash queue, (err)->
            console.error err if err

    JUser.on "UserUnblocked", (user)->
      selector =
        'users.id'    : user.getId()
        'users.owner' : yes

      JVM.some selector, {}, (err, vms)->
        return console.error err  if err
        queue = vms.map (vm)->->
          vm.update { $set: { hostKite: null } }, -> queue.fin()
        if queue.length > 0
          dash queue, (err)->
            console.error err if err

    JAccount.on 'UsernameChanged', ({ oldUsername, username, isRegistration })->
      return  unless oldUsername and username

      if isRegistration
        oldGroup  = 'guests'
        group     = 'koding'
      else
        oldGroup = group = 'koding'

      hostnameAlias = "vm-0.#{oldUsername}.#{oldGroup}.kd.io"
      newHostNameAlias = "vm-0.#{username}.#{group}.kd.io"

      console.log "Started to migrate #{oldUsername} to #{username} ..."

      JVM.one {hostnameAlias}, (err, vm)=>
        return console.error err  if err or not vm
        # Old vm found

        # Removing old vm domains...
        JVM.removeRelatedDomains vm, (err)=>
          if err
            console.error "Failed to remove old domains for #{hostnameAlias}"

          JAccount.one {'profile.nickname':username}, (err, account)=>
            return console.error err  if err or not account
            # New account found
            webHome       = username
            vm.update {$set: {hostnameAlias:newHostNameAlias, webHome}},(err)=>

              return console.error err  if err
              # VM hostnameAlias updated

              nameFactory = (require 'koding-counter')
                db          : JVM.getClient()
                offset      : 0
                counterName : "koding~#{username}~"
              nameFactory.next (err, uid)=>
                return console.error err  if err
                # Counter created

                hostnameAliases = JVM.createAliases {
                  nickname:username
                  type:'user', uid, groupSlug:'koding'
                }
                JVM.createDomains account, hostnameAliases, hostnameAliases[0]

                console.log """Migration completed for
                               #{hostnameAlias} to #{newHostNameAlias}"""

    JGroup.on 'GroupDestroyed', (group)->
      group.fetchVms (err, vms)->
        if err then handleError err
        else vms.forEach (vm)-> vm.remove handleError

    JGroup.on 'MemberAdded', ({group, member})->
      member.fetchUser (err, user)->
        if err then handleError err
        else if group.slug is 'guests'
          # Following is just here to register this name in the counters collection
          ((require 'koding-counter') {
            db          : JVM.getClient()
            counterName : "koding~#{member.profile.nickname}~"
            offset      : 0
          }).next ->

          # TODO: this special case for koding should be generalized for any group.
          addVm {
            user
            account   : member
            sudo      : yes
            type      : 'user'
            target    : member
            planCode  : 'free'
            planOwner : "user_#{member._id}"
            groupSlug : group.slug
            webHome   : user.username
            groups    : wrapGroup group
          }
        else if group.slug is 'koding'
          member.fetchVms (err, vms)->
            if err then handleError err
            else
              vms.forEach (vm) ->
                vm.update $set: groups: [id: group.getId()], handleError
        else
          member.checkPermission group, 'sudoer', (err, hasPermission)->
            if err then handleError err
            else
              group.fetchVms (err, vms)->
                if err then handleError err
                else vms.forEach (vm)->
                  if vm.type is 'group'
                    vm.update {
                      $addToSet: users: { id: user.getId(), sudo: hasPermission }
                    }, handleError

    JGroup.on 'MemberRemoved', ({group, member})->
      member.fetchUser (err, user)->
        if err then handleError err
        # Do we need to take care guests here? Like when guests ends up session
        # Do we also need to remove their vms? ~ GG
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
