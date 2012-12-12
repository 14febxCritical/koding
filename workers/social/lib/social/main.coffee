log = -> logger.info arguments...

{argv} = require 'optimist'

{exec} = require 'child_process'
{extend} = require 'underscore'

process.on 'uncaughtException', (err)->
  exec './beep'
  console.log err, err?.stack

Bongo = require 'bongo'
Broker = require 'broker'

Object.defineProperty global, 'KONFIG', value: require './config'
{mq, mongo, email, social} = KONFIG

mqOptions = extend {}, mq
mqOptions.login = social.login if social?.login?

broker = new Broker mqOptions

processMonitor = (require 'processes-monitor').start
  name : "Social Worker #{process.pid}"
  interval : 1000
  limits  :
    memory   : 300
    callback : (name,msg,details)->
      console.log "[SOCIAL WORKER #{name}] I'm using too much memory, feeling suicidal."
      process.exit()
  die :
    after: "non-overlapping, random, 3 digits prime-number of minutes"
    middleware : (name,callback) -> koding.disconnect callback
    # TEST AMQP WITH THIS CODE. IT THROWS THE CHANNEL ERROR.
    # middleware : (name,callback) ->
    #   koding.disconnect ->
    #     console.log "[SOCIAL WORKER #{name}] is reached end of its life, will die in 10 secs."
    #     setTimeout ->
    #       callback null
    #     ,10*1000
    middlewareTimeout : 15000
  # mixpanel:
  #   key : KONFIG.mixpanel.key

koding = new Bongo
  root        : __dirname
  mongo       : mongo
  models      : './models'
  queueName   : social.queueName
  mq          : broker
  fetchClient :(sessionToken, context, callback)->
    [callback, context] = [context, callback] unless callback
    context ?= 'koding'
    callback ?= ->
    koding.models.JUser.authenticateClient sessionToken, context, (err, account)->
      if err
        koding.emit 'error', err
      else
        callback {sessionToken, connection:delegate:account}

koding.on 'auth', (exchange, sessionToken)->
  koding.fetchClient sessionToken, (client)->
    {delegate} = client.connection

    if delegate instanceof koding.models.JAccount
      koding.models.JAccount.emit "AccountAuthenticated", delegate
      
    koding.handleResponse exchange, 'changeLoggedInState', [delegate]

koding.connect ->
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

console.log 'Koding Social Worker has started.'
