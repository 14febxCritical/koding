JBundle = require '../bundle'

module.exports = class JGroupBundle extends JBundle

  KodingError = require '../../error'

  {permit} = require '../group/permissionset'

  {groupBy} = require 'underscore'

  {dash} = require 'bongo'

  @share()

  @trait __dirname, '../../traits/protected'

  @set
    sharedEvents      :
      static          : []
      instance        : []
    sharedMethods     :
      static          : ['fetchPlans']
      instance        : ['fetchLimits', 'debit']
    permissions       :
      'manage payment methods'  : []
      'change bundle'           : []
      'request bundle change'   : ['member','moderator']
      'commission resources'    : ['member','moderator']
    limits            :
      'cpu'           : { unit: 'core', quota: 1 }
      'ram'           : { unit: 'GB',   quota: 0.25 }
      'disk'          : { unit: 'GB',   quota: 0.5 }
      'users'         : { unit: 'user', quota: 20 }
      'cpu per user'  : { unit: 'core', quota: 0 }
      'ram per user'  : { unit: 'GB',   quota: 0 }
      'disk per user' : { unit: 'GB',   quota: 0 }
    schema            :
      overagePolicy   :
        type          : String
        enum          : [
          'unknown value for overage'
          ['allowed', 'by permission', 'not allowed']
        ]
        default       : 'not allowed'

  @parsePlanKey = (key)->
    [ prefix, category, resource, upperBound ] = key.split '_'
    return { prefix, category, resource, upperBound: +upperBound }

  @fetchPlans = permit 'commission resources',
    success: (client, callback) ->
      (require 'koding-payment').getPlans (err, plans) =>
        return callback err  if err

        formattedPlans = plans.map (plan) =>
          feeInitial  : plan.feeInitial
          feeMonthly  : plan.feeMonthly
          code        : plan.code
          usage       : @parsePlanKey plan.code
          title       : plan.title

        byCategory = groupBy formattedPlans, (plan)-> plan.usage.category

        for own category, group of byCategory
          byCategory[category] = groupBy group, (plan)-> plan.usage.resource

        callback null, byCategory


  fetchLimits$: permit 'change bundle',
    success: (client, callback)-> @fetchLimits callback

  debit$: do ->

    debit = (limit, debitAmount, callback = (->)) ->
      limit.update { $inc: usage: debitAmount }, callback

    permit 'commission resources',
      success: (client, debits, callback) ->
        JVM = require '../vm'
        {connection:{delegate}, context:{group}} = client
        {overagePolicy} = this
        JVM.calculateUsage delegate, group, (err, usage) =>
          return callback err  if err?
          @fetchLimits (err, limits) =>
            return callback err  if err

            limitsMap = limits.reduce( (acc, limit) ->
              acc[limit.title] = limit
              return acc
            , {})

            queue = []

            limits.forEach (limit) ->

              debitAmount   = debits[limit.title]
              personalLimit = limitsMap["#{limit.title} per user"]

              theyHaveEnough =
                ( debitAmount? and personalLimit? )   and
                ( not /per user$/.test limit.title )  and
                ( debitAmount <= limit )              and
                (( overagePolicy is 'allowed' ) or
                 ( debitAmount <= personalLimit ))

              if theyHaveEnough
                queue.push ->
                  debit limit, debitAmount
                  debit personalLimit, debitAmount

              return

            if queue.length and queue.length is (Object.keys debits).length
              dash queue, ->
                options     =
                  usage     : debits
                  account   : delegate
                  groupSlug : group
                JVM.createVm options, (err)-> callback err

            else
              callback new KodingError 'Insufficient quota.'
