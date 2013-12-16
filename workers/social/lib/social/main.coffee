log = -> logger.info arguments...

{argv} = require 'optimist'

{exec} = require 'child_process'
{extend} = require 'underscore'

process.on 'uncaughtException', (err)->
  exec './beep'
  console.log err, err?.stack

Bongo = require 'bongo'
Broker = require 'broker'

KONFIG = require('koding-config-manager').load("main.#{argv.c}")
Object.defineProperty global, 'KONFIG', value: KONFIG
{mq, email, social, client:{runtimeOptions:{precompiledApi}}, mongoReplSet} = KONFIG

mongo = "mongodb://#{KONFIG.mongo}?auto_reconnect"  if 'string' is typeof KONFIG.mongo

mqOptions = extend {}, mq
mqOptions.login = social.login if social?.login?

broker = new Broker mqOptions

processMonitor = (require 'processes-monitor').start
  name : "Social Worker #{process.pid}"
  stats_id: "worker.social." + process.pid
  interval : 30000
  librato: KONFIG.librato
  limit_hard  :
    memory   : 300
    callback : (name,msg,details)->
      console.log "[SOCIAL WORKER #{name}] Using excessive memory, exiting."
      process.exit()
  die :
    after: "non-overlapping, random, 3 digits prime-number of minutes"
    middleware : (name,callback) -> koding.disconnect callback
    middlewareTimeout : 15000
  # WE'RE NOT SURE IF THIS SOFT LIMIT WAS A GOOD IDEA OR NOT
  # limit_soft:
  #   memory: 200
  #   callback: (name, msg, details) ->
  #     console.log "[SOCIAL WORKER #{name}] Using too much memory, accepting no more new jobs."
  #     process.send?({pid: process.pid, exiting: yes})
  #     koding.disconnect()
  #     setTimeout ->
  #       process.exit()
  #     , 20000
  # DISABLED TO TEST MEMORY LEAKS
  # die :
  #   after: "non-overlapping, random, 3 digits prime-number of minutes"
  #   middleware : (name,callback) -> koding.disconnect callback
  #   # TEST AMQP WITH THIS CODE. IT THROWS THE CHANNEL ERROR.
  #   # middleware : (name,callback) ->
  #   #   koding.disconnect ->
  #   #     console.log "[SOCIAL WORKER #{name}] is reached end of its life, will die in 10 secs."
  #   #     setTimeout ->
  #   #       callback null
  #   #     ,10*1000
  #   middlewareTimeout : 15000
  # toobusy:
  #   interval: 10000
  #   callback: ->
  #     console.log "[SOCIAL WORKER #{name}] I'm too busy, accepting no more new jobs."
  #     process.send?({pid: process.pid, exiting: yes})
  #     koding.disconnect()
  #     setTimeout ->
  #       process.exit()
  #      , 20000

koding = new Bongo {
  precompiledApi
  verbose     : social.verbose
  root        : __dirname
  mongo       : mongoReplSet or mongo
  models      : './models'
  resourceName: social.queueName
  mq          : broker
  fetchClient :(sessionToken, context, callback)->
    { JUser, JAccount } = koding.models
    [callback, context] = [context, callback] unless callback
    context             ?= group: 'koding'
    callback            ?= ->
    JUser.authenticateClient sessionToken, context, (err, account)->
      if err
        koding.emit 'error', err
      else if account instanceof JAccount
        callback {sessionToken, context, connection:delegate:account}
      else
        console.log "this is not a proper account".red
        console.log ''+account.constructor.pid
        console.log ''+JAccount.pid
        console.log JAccount is account.constructor
        # koding.emit 'error', message: 'this is not a proper account'
}

koding.on 'authenticateUser', (client, callback)->
  {delegate} = client.connection
  callback delegate

koding.connect ->
  (require './init').init koding

  # create default roles for groups
  JGroupRole = require './models/group/role'

  JGroupRole.createDefaultRoles (err)->
    if err then console.log err.message
    else console.log "Default group roles created!"

  if KONFIG.misc?.claimGlobalNamesForUsers
    require('./models/account').reserveNames console.log

  if KONFIG.misc?.updateAllSlugs
    require('./traits/slugifiable').updateSlugsByBatch 100, [
      require './models/tag'
      require './models/app'
      require './models/messages/codesnip'
      require './models/messages/discussion'
      require './models/messages/tutorial'
    ]

  if KONFIG.misc?.debugConnectionErrors then
    # console.log 'ffaafafafaf'
    # TEST AMQP WITH THIS CODE. IT THROWS THE CHANNEL ERROR.
    # koding.disconnect ->
    #   console.log "[SOCIAL WORKER #{name}] is reached end of its life, will die in 10 secs."
    #   setTimeout ->
    #     process.exit()
    #   ,10*1000

console.log "Koding Social Worker #{process.pid} has started."

# require './followfeed' # side effects

