jraphical = require 'jraphical'

JAccount = require '../account'
JUser = require '../user'
JVM = require '../vm'
KodingError = require '../../error'


module.exports = class JReferral extends jraphical.Message

  {Relationship} = jraphical

  {race, secure, dash} = require 'bongo'

  @share()

  schema =
    # for now we only have disk space
    type              :
      type            : String
    unit              :
      type            : String
    amount            :
      type            : Number
    createdAt         :
      type            : Date
      default         : -> new Date

  @set
    sharedMethods     :
      static          : ['redeem', 'fetchRedeemableReferrals', 'fetchReferredAccounts' ]
      instance        : [ ]
    schema            : schema
    relationships     :
      redeemedOn      :
        targetType    : 'JVM'
        as            : 'redeemedOn'

  @getReferralEarningLimits = (type) ->
    switch type
      when "disk" then return 16000
      else return console.error "Unknown referral query limit"

  # Simply find the unused referrals
  # me-[:referrer]->JReferral<-[:referred]-JAccount
  @fetchRedeemableReferrals = secure (client, query, callback)->
    # check for type of request
    allowedTypes = ["disk"]
    return callback new KodingError "Request is not valid" unless query.type in allowedTypes

    @fetchOwnReferralsIds client, { type: query.type }, {}, (err, allReferalIds) =>
      return callback err if err

      @fetchUsedReferrals allReferalIds, (err, usedReferrals) =>
        return callback err if err

        # aggregate the used referrals
        usedRefIds = []
        usedRefIds.push "#{usedReferral._id}" for usedReferral in usedReferrals when id not in usedRefIds

        # find the diff of unused referrals
        unusedRefIds = []
        unusedRefIds.push id for id in allReferalIds when id not in usedRefIds

        return callback null, [] if unusedRefIds.length < 1

        refSelector = { _id: $in: unusedRefIds }
        JReferral.some refSelector, {}, (err, unusedReferrals)=>
          return callback err if err

          # find the total used referred disk spacea
          totalUsedReferalAmount = 0
          totalUsedReferalAmount += ref.amount for ref in usedReferrals

          limit = @getReferralEarningLimits(query.type)
          # find the usable amount
          usableReferralSize = limit - totalUsedReferalAmount
          # if user consumed their quota return an error
          # this is a special case for used up quota
          return callback new KodingError "You have used your quota for referral system" if usableReferralSize <= 0

          # gather usable referrals
          usableReferrals = []
          for unusedRef in unusedReferrals
            usableReferralSize -= unusedRef.amount
            # when we go under the limit, do not continue
            break if usableReferralSize < 0
            usableReferrals.push unusedRef

          callback null, usableReferrals


  @fetchUsedReferrals = (allReferalIds, callback)->

    usedReferralsSelector = {
      sourceId    : { $in: allReferalIds },
      sourceName  : 'JReferral',
      targetName  : 'JVM',
      as          : 'redeemedOn'
    }

    Relationship.some usedReferralsSelector, {}, (err, usedReferralsRels)=>
      return callback err if err

      usedRefIds = usedReferralsRels.map (rel) -> rel.sourceId

      JReferral.some { _id: $in: usedRefIds }, {}, callback

  @fetchOwnReferralsIds = (client, query, options, callback)->
    account = client.connection.delegate

    # find user's relationships as referrer to the referral system
    selector = {
      sourceId    : account.getId(),
      sourceName  : 'JAccount',
      targetName  : 'JReferral',
      as          : 'referrer'
    }

    Relationship.count selector, (err, count) =>
      return callback err if err
      options.targetOptions = { selector: query }
      @fetchOwnReferralsIdsInBatch count, 100, selector, options, (err, relationships)->
        allReferalIds = relationships.map (rel) -> "#{rel.targetId}"
        callback null, allReferalIds


  @fetchOwnReferralsIdsInBatch = (totalCount, batchCount, selector, options, callback)->
    teasers = []
    collectRels = race (i, step, fin)->
      options.skip  = batchCount * (step - 1)
      options.limit = batchCount
      Relationship.some selector, options, (err, relationships)=>
        if err
          callback err
          fin()
        else if not relationships
          fin()
        else
          teasers.push rel for rel in relationships
          fin()
    , ->
      callback null, teasers
    totalStep = Math.floor(totalCount/batchCount)
    totalStep = if totalStep <= 0 then 1 else totalStep
    while totalStep
      collectRels totalStep
      totalStep--

  @fetchReferredAccounts = secure (client, query, options, callback)->
    username = client.connection.delegate.profile.nickname
    JAccount.some { referrerUsername : username }, options, callback

  @redeem = secure (client, data, callback)->
    {vmName, size, type} = data
    return callback new KodingError "Request is not valid" unless vmName and size

    # get redeemable referals
    @fetchRedeemableReferrals client, {type}, (err, referrals)=>
      return callback err if err

      # check user has enough credit
      # for loop also checks for 0 length referrals
      totalCredit = 0
      totalCredit += referral.amount for referral in referrals

      # if not return an error
      return callback new KodingError "You dont have enough credit to redeem" if size > totalCredit

      # fetch user's vmName which will be upgraded
      @fetchUserVM client, vmName, (err, vm)=>
        return callback err if err
        options =
          referrals :referrals
          vm        :vm
          size      :size
          type      :type

        @relateReferalsToJVM options, callback

  @createUpdateQueryForRedeem = (type, amount) ->
    switch type
      when "disk" then return 'diskSizeInMB': amount
      else
        return console.error "Invalid type provided"

  @relateReferalsToJVM = (options, callback) ->
    {referrals, vm, size, type} = options
    # generate the referals to be used for upgrade process
    referralsToBeUsed = []
    addedSize = 0
    for referral in referrals
      break if addedSize >= size
      addedSize += referral.amount
      referralsToBeUsed.push referral

    # wrap the callback
    kallback = (err)=>
      return callback err if err

      returnValue =
        addedSize    : addedSize
        vm           : vm.hostnameAlias
        type         : type
        unit         : referrals.first.unit

      updateQuery = @createUpdateQueryForRedeem type, addedSize

      vm.update { $inc: updateQuery }, (err) ->
        return callback err if err
        callback null, returnValue

    queue = referralsToBeUsed.map (ref)=>=>
      ref.addRedeemedOn vm, (err)->
        return kallback err if err
        queue.fin()

    dash queue, kallback


  @fetchUserVM = (client, vmName, callback)->
    account = client.connection.delegate

    # get the user to fetch his/her VMs
    account.fetchUser (err, user) ->
      return callback err  if err
      selector =
        users:
          $elemMatch:
            id: user.getId()
        hostnameAlias: vmName
      # get user's vms
      JVM.one selector, (err, vm)->
        return callback err  if err
        return callback new KodingError "#{vm} is not found" unless vm
        callback null, vm

  do =>
    JAccount.on 'AccountRegistered', (me, referrerCode)->
      return console.error "Account is not defined in event" unless me
      return console.log "User dont have any referrer" unless referrerCode
      if me.profile.nickname is referrerCode
          return console.error "#{me.profile.nickname} - User tried to refer themself"

      me.update { $set : 'referrerUsername' :  referrerCode }, (err)->
        return console.error err if err
        console.log "referal saved successfully for #{me.profile.nickname} from #{referrerCode}"

    JUser.on 'EmailConfirmed', (user)->
      return console.log "User is not defined in event" unless user

      user.fetchOwnAccount (err, me)->
        return console.error err if err
        # if account not fonud then do nothing and return
        return console.error "Account couldnt found" unless me
        referrerUsername = me.referrerUsername
        return console.log "User doesn't have any referrer" unless referrerUsername
        # get referrer
        JAccount.one {'profile.nickname': referrerUsername }, (err, referrer)->
          # if error occured than do nothing and return
          return console.error "Error while fetching referrer", err if err
          # if referrer not fonud then do nothing and return
          return console.error "Referrer couldnt found" if not referrer
          referral = new JReferral { type: "disk", unit: "MB", amount: 250 }
          referral.save (err) ->
            return console.error err if err
            #add referrer as referrer to the referral system
            referrer.addReferrer referral, (err)->
              return console.error err if err
              # add me as referred to the referral system
              me.addReferred referral, (err)->
                return console.error err if err
                console.log "referal saved successfully for #{me.profile.nickname} from #{referrerUsername}"
