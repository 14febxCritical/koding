{Model} = require 'bongo'
{Relationship, Module} = require 'jraphical'
{argv} = require 'optimist'
KONFIG = require('koding-config-manager').load("main.#{argv.c}")

module.exports = class JVM extends Module

  {permit} = require './group/permissionset'
  {secure, dash, signature} = require 'bongo'
  {uniq}   = require 'underscore'

  {argv} = require 'optimist'

  KodingError = require '../error'

  JPaymentSubscription = require './payment/subscription'
  JPaymentPack         = require './payment/pack'
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

      static            :
        fetchVms: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchVmsByContext: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchVmInfo:
          (signature String, Function)
        fetchDomains:
          (signature String, Function)
        removeByHostname:
          (signature String, Function)
        someData:
          (signature Object, Object, Object, Function)
        count:
          (signature Object, Function)
        fetchDefaultVm:
          (signature Function)
        fetchVmRegion:
          (signature String, Function)
        createVmByNonce:
          (signature String, Function)
        createFreeVm:
          (signature Function)
        createSharedVm:
          (signature Function)
    schema              :
      ip                :
        type            : String
        default         : -> null
      ldapPassword      :
        type            : String
        default         : -> null
      hostnameAlias     :
        type            : String
        required        : yes
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
      planCode          : String
      subscriptionCode  : String
      vmType            :
        type            : String
        default         : 'user'
      users             : Array
      groups            : Array
      isEnabled         :
        type            : Boolean
        default         : yes
      shouldDelete      :
        type            : Boolean
        default         : no
      pinnedToHost      : String
      alwaysOn          :
        type            : Boolean
        default         : no
      maxMemoryInMB     :
        type            : Number
        default         : KONFIG.defaultVMConfigs.freeVM.ram ? 1024
      diskSizeInMB      :
        type            : Number
        default         : KONFIG.defaultVMConfigs.freeVM.storage ? 3600
      numCPUs           :
        type            : Number
        default         : KONFIG.defaultVMConfigs.freeVM.cpu ? 1

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
        if err
        then console.error err  unless err.code is 11000
        else updateRelationship domainObj

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
      if groupSlug in ['koding', 'guests']
        requiredDomains.push "#{nickname}.#{domain}"
    else
      requiredDomains = ["#{groupSlug}.#{domain}", "shared.#{groupSlug}.#{domain}"]
    @createDomains account, requiredDomains, vm.hostnameAlias

  @createAliases = ({nickname, type, uid, groupSlug})->
    domain       = 'kd.io'
    aliases      = []
    type        ?= 'user'

    if type in ['user', 'expensed']
      if uid is 0
        aliases.push "#{nickname}.#{groupSlug}.#{domain}"
      if groupSlug in ['koding', 'guests']
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

  @createFreeVm = secure (client, callback)->

    @fetchDefaultVm client, (err, vm)=>

      return callback err  if err

      { delegate: account } = client.connection

      unless vm

        JGroup = require './group'
        JGroup.one slug:'koding', (err, group)=>

          account.fetchUser (err, user) =>
            return callback err  if err
            return callback new Error "user not found" unless user

            nameFactory = (require 'koding-counter')
              db          : JVM.getClient()
              offset      : 0
              counterName : "koding~#{user.username}~"

            nameFactory.next (err, uid)=>
              return console.error err  if err
              # Counter created

              @addVm {
                uid
                user
                account
                sudo      : yes
                type      : 'user'
                target    : account
                planCode  : 'free'
                groupSlug : group.slug
                planOwner : "user_#{account._id}"
                webHome   : account.profile.nickname
                groups    : wrapGroup group
              }, callback

      else

        callback new KodingError('Default VM already exists'), vm

  vmProductMap =
    "f34ba4e35041fea7e519dc20a96d3e1b": { core  : 1 }
    "04d5a80edbde8c2b4be2c4fc0da4d527": { ram   : 1024 }
    "7029c74b6f16ed328cd1c41a454c02f3": { disk  : 1200 }

  @createVmByNonce = secure (client, nonce, callback) ->
    JPaymentFulfillmentNonce  = require './payment/nonce'
    JPaymentPack              = require './payment/pack'

    JPaymentFulfillmentNonce.one { nonce }, (err, nonceObject) =>
      return callback err  if err
      return { message: "Unrecognized nonce!", nonce }  unless nonceObject

      { planCode, subscriptionCode } = nonceObject

      JPaymentPack.one { planCode }, (err, pack) =>
        return callback err  if err

        pack.fetchProducts (err, products) =>
          return callback err  if err

          { delegate: account } = client.connection
          { group: groupSlug } = client.context

          attributes = products
            .map (product) ->
              vmProductMap[product.planCode]
            .reduce( (memo, attr) ->
              memo[key] = val  for own key, val of attr
              memo
            , {})

          @createVm {
            account
            groupSlug
            planCode
            subscriptionCode
            type          : 'user'
            maxMemoryInMB : attributes.ram
            diskSizeInMB  : attributes.disk
            numCPUs       : attributes.core
          }, (err, vm) ->
            return callback err  if err

            callback null, vm


  @createSharedVm = secure (client, callback)->
    {connection:{delegate:account}, context:{group}} = client
    JGroup = require './group'
    JGroup.one {slug:group}, (err, group)=>
      return callback err  if err
      group.fetchAdmins (err, admins)=>
        return callback err  if err

        adminIds = admins.map (admin) ->
          admin.getId().toString()

        return callback new Error "You can not create shared VM" unless account.getId().toString() in adminIds

        request =
          account   :account,
          type      :"group"
          # groupSlug :"dede",
          groupSlug :group.slug,
          # i dont know what the plan code is!?!
          planCode  : "group_vm_1xs_1"
          # this is not used
          # subscriptionCode:subscriptionCode

        @createVm request, callback

  # TODO: this needs to be rethought in terms of bundles, as per the
  # discussion between Devrim, Chris T. and Badahir  C.T.
  @createVm = ({account, type, groupSlug, planCode, subscriptionCode}, callback)->
    JGroup = require './group'
    JGroup.one {slug: groupSlug}, (err, group)=>
      return callback err  if err
      return callback new Error "Group not found"  unless group

      account.fetchUser (err, user)=>
        return callback err  if err
        return callback new Error "user is not defined"  unless user

        # We are keeping this names just for counter
        {nickname} = account.profile
        webHome    = if type is "group" then groupSlug else nickname

        counterName = "#{groupSlug}~#{nickname}~"
        nameFactory = (require 'koding-counter') {
          db     : JVM.getClient()
          offset : 0
          counterName
        }

        nameFactory.next (err, uid)=>
          return callback err  if err

          hostnameAliases = JVM.createAliases {
            nickname, type, uid, groupSlug
          }
          users         = [{ id: user.getId(), sudo: yes, owner: yes }]
          groups        = [{ id: group.getId() }]
          hostnameAlias = hostnameAliases[0]

          vm = new JVM {
            hostnameAlias
            planCode
            subscriptionCode
            webHome
            groups
            users
            vmType: type
          }

          vm.save (err) =>

            if err
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
    # todo - do this operation in batches
    selector =
      sourceId    : group.getId()
      sourceName  : "JGroup"
      as          : "member"

    # fetch members of the group
    Relationship.someData selector, {targetId:1}, (err, cursor)->
      return callback err  if err

      cursor.toArray (err, targetIds)->
        return callback err  if err
        targetIds or= []

        # aggregate them into accountIds
        accountIds = targetIds.map (rec)-> rec.targetId

        selector =
          targetId   : {$in : accountIds}
          targetName : "JAccount"
          as         : 'owner'
          sourceName : 'JUser'

        # fetch userids of the accounts
        Relationship.someData selector, {sourceId:1}, (err, cursor)->
          return callback err  if err

          cursor.toArray (err, sourceIds)->
            return callback err  if err
            sourceIds or= []
            vmUsers = []

            vmUsers = sourceIds.map (rec)->
              { id: rec.sourceId, sudo: yes }

            return vm.update {
              $set: users: vmUsers
            }, callback

  @fetchVmInfo = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection

    delegate.fetchUser (err, user) ->
      return callback err  if err
      return callback new Error "user not found" unless user

      JVM.one
        hostnameAlias : hostnameAlias
        users         : { $elemMatch: id: user.getId() }
      , (err, vm)->
        return callback err  if err
        return callback null, null  unless vm
        callback null,
          planCode         : vm.planCode
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
      return callback new Error "user not found" unless user

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
      return callback new Error "user not found" unless user

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
      return callback new Error "user not found" unless user

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
      JPaymentSubscription.one
        planCode : vm.subscriptionCode
        $or      : [
          {status: 'active'}
          {status: 'canceled'}
        ]
      , (err, subscription)->
        if err or not subscription
          return callback { message: 'Unable to update subscription.' }

        if subscription.status is 'canceled'
          vm.remove callback
        else
          JPaymentPack.one { planCode: vm.planCode }, (err, pack) ->
            return callback err  if err

            subscription.credit pack, (err) ->
              return callback err  if err

              vm.remove callback

  @removeByHostname = secure (client, hostnameAlias, callback)->
    {delegate} = client.connection

    delegate.fetchUser (err, user) =>
      return callback err  if err
      return callback { message: "user not found" }  unless user

      selector =
        hostnameAlias : hostnameAlias
        users         : { $elemMatch: id: user.getId(), owner: yes }

      JVM.one selector, (err, vm) =>
        return callback err  if err
        return callback new KodingError 'No such VM'  unless vm

        delegate.hasTarget vm, 'owner', (err, hasTarget) =>
          return callback err  if err

          if hasTarget
            @deleteVM vm, callback
          else
            [{ id: groupId }] = vm.groups

            JGroup = require './group'
            JGroup.one { _id: groupId }, (err, group)=>
              return callback err  if err

              JPermissionSet.checkPermission client, "delete vms", group,
              (err, hasPermission)=>
                return callback err  if err

                @deleteVM vm, callback  if hasPermission

  @addVm = ({ account, target, user, sudo, groups, groupSlug
             type, planCode, planOwner, webHome, uid }, callback)->

    return handleError new Error "user is not defined"  unless user
    nickname = account.profile.nickname or user.username
    uid ?= 0
    hostnameAliases = JVM.createAliases {
      nickname
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

      callback? err, vm  unless err

      handleError err
      if err
        return console.warn "Failed to create VM for ", \
                             {users, groups, hostnameAlias}

      JVM.ensureDomainSettings \
        {account, vm, type, nickname, groupSlug}
      JVM.createDomains account, hostnameAliases, hostnameAlias
      target.addVm vm, handleError

  wrapGroup = (group)-> [ { id: group.getId() } ]

  do ->

    JAccount  = require './account'
    JGroup    = require './group'
    JUser     = require './user'

    uidFactory = null

    require('bongo').Model.on 'dbClientReady', ->
      uidFactory = (require 'koding-counter') {
        db          : JVM.getClient()
        counterName : 'uid'
        offset      : 1e6
      }
      uidFactory.initialize()

    JUser.on 'UserCreated', (user)->
      uidFactory.next (err, uid)->
        if err then handleError err
        else user.update { $set: { uid } }, handleError

    JUser.on "UserBlocked", (user)->
      return handleError new Error "user not found" unless user
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
      return handleError new Error "user not found" unless user
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
        return handleError err  if err
        return handleError new Error "user not defined" unless user

        if group.slug is 'guests'
          # Following is just here to register this name in the counters collection
          ((require 'koding-counter') {
            db          : JVM.getClient()
            counterName : "koding~#{member.profile.nickname}~"
            offset      : 0
          }).next ->

          # TODO: this special case for koding should be generalized for any group.
          JVM.addVm {
            user
            account   : member
            sudo      : yes
            type      : 'user'
            target    : member
            planCode  : 'free'
            planOwner : "user_#{member._id}"
            groupSlug : group.slug
            webHome   : member.profile.nickname
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
        return handleError err  if err
        return handleError new Error "user not found" unless user

        # Do we need to take care guests here? Like when guests ends up session
        # Do we also need to remove their vms? ~ GG
        if group.slug is 'koding'
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
        return handleError err  if err
        return handleError new Error "user not found"  unless user

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
