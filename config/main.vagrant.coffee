fs = require 'fs'
nodePath = require 'path'

deepFreeze = require 'koding-deep-freeze'

version = "0.0.1" #fs.readFileSync nodePath.join(__dirname, '../.revision'), 'utf-8'

mongo = 'dev:k9lc4G1k32nyD72@web0.dev.system.aws.koding.com:27017/koding_dev2_copy'

projectRoot = nodePath.join __dirname, '..'

# rabbitPrefix = (
#   try fs.readFileSync nodePath.join(projectRoot, '.rabbitvhost'), 'utf8'
#   catch e then ""
# ).trim()

socialQueueName = "koding-social-vagrant"

module.exports = deepFreeze
  aws           :
    key         : 'AKIAJSUVKX6PD254UGAA'
    secret      : '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'
  uri           :
    address     : "http://koding.local"
  projectRoot   : projectRoot
  version       : version
  webserver     :
    login       : 'prod-webserver'
    port        : 3020
    clusterSize : 2
    queueName   : socialQueueName+'web'
    watch       : yes
  mongo         : mongo
  runGoBroker   : yes
  watchGoBroker : no
  compileGo     : yes
  buildClient   : yes
  misc          :
    claimGlobalNamesForUsers: no
    updateAllSlugs : no
    debugConnectionErrors: yes
  uploads       :
    enableStreamingUploads: no
    distribution: 'https://d2mehr5c6bceom.cloudfront.net'
    s3          :
      awsAccountId        : '616271189586'
      awsAccessKeyId      : 'AKIAJO74E23N33AFRGAQ'
      awsSecretAccessKey  : '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'
      bucket              : 'koding-uploads'
  # loadBalancer  :
  #   port        : 3000
  #   heartbeat   : 5000
    # httpRedirect:
    #   port      : 80 # don't forget port 80 requires sudo
  bitly :
    username  : "kodingen"
    apiKey    : "R_677549f555489f455f7ff77496446ffa"
  authWorker    :
    login       : 'prod-auth-worker'
    queueName   : socialQueueName+'auth'
    authResourceName: 'auth'
    numberOfWorkers: 1
    watch       : yes
  social        :
    login       : 'prod-social'
    numberOfWorkers: 1
    watch       : yes
    queueName   : socialQueueName
  cacheWorker   :
    login       : 'prod-social'
    watch       : yes
    queueName   : socialQueueName+'cache'
    run         : no
  feeder        :
    queueName   : "koding-feeder"
    exchangePrefix: "followable-"
    numberOfWorkers: 1
  presence      :
    exchange    : 'services-presence'
  client        :
    version     : version
    watch       : no
    includesPath: 'client'
    websitePath : 'website'
    js          : "js/kd.#{version}.js"
    css         : "css/kd.#{version}.css"
    indexMaster : "index-master.html"
    index       : "index.html"
    useStaticFileServer: no
    staticFilesBaseUrl: 'http://koding.local'
    runtimeOptions:
      resourceName: socialQueueName
      suppressLogs: no
      broker    :
        sockJS  : 'http://koding.local:8008/subscribe'
      apiUri    : 'https://dev-api.koding.com'
      # Is this correct?
      version   : version
      mainUri   : 'http://koding.local'
      appsUri   : 'https://dev-app.koding.com'
      sourceUri : 'http://koding.local:1337'
  mq            :
    host        : 'localhost'
    login       : 'PROD-k5it50s4676pO9O'
    componentUser: "PROD-k5it50s4676pO9O"
    password    : 'djfjfhgh4455__5'
    heartbeat   : 10
    vhost       : '/'
  broker        :
    port        : 8008
    certFile    : ""
    keyFile     : ""
  kites:
    disconnectTimeout: 3e3
    vhost       : 'kite'
  email         :
    host        : 'koding.local'
    protocol    : 'http:'
    defaultFromAddress: 'hello@koding.com'
  emailWorker   :
    cronInstant : '*/10 * * * * *'
    cronDaily   : '0 10 0 * * *'
    run         : no
    defaultRecepient : undefined
  guests        :
    # define this to limit the number of guset accounts
    # to be cleaned up per collection cycle.
    poolSize        : 1e4
    batchSize       : undefined
    cleanupCron     : '*/10 * * * * *'
  logger            :
    mq              :
      host          : 'web0.dev.system.aws.koding.com'
      login         : 'guest'
      password      : 's486auEkPzvUjYfeFTMQ'
  pidFile       : '/tmp/koding.server.pid'
  loggr:
    push: no
    url: ""
    apiKey: ""
  librato:
    push: no
    email: ""
    token: ""
    interval: 60000

  # crypto :
  #   encrypt: (str,key=Math.floor(Date.now()/1000/60))->
  #     crypto = require "crypto"
  #     str = str+""
  #     key = key+""
  #     cipher = crypto.createCipher('aes-256-cbc',""+key)
  #     cipher.update(str,'utf-8')
  #     a = cipher.final('hex')
  #     return a
  #   decrypt: (str,key=Math.floor(Date.now()/1000/60))->
  #     crypto = require "crypto"
  #     str = str+""
  #     key = key+""
  #     decipher = crypto.createDecipher('aes-256-cbc',""+key)
  #     decipher.update(str,'hex')
  #     b = decipher.final('utf-8')
  #     return b
