fs = require 'fs'
nodePath = require 'path'

deepFreeze = require 'koding-deep-freeze'

version = (fs.readFileSync nodePath.join(__dirname, '../VERSION'), 'utf-8').trim()

# PROD
mongo = 'PROD-koding:34W4BXx595ib3J72k5Mh@localhost:27017/beta_koding'

projectRoot = nodePath.join __dirname, '..'

rabbitPrefix = ((
  try fs.readFileSync nodePath.join(projectRoot, '.rabbitvhost'), 'utf8'
  catch e then require("os").hostname()
).trim())+"-dev-#{version}"
rabbitPrefix = rabbitPrefix.split('.').join('-')

socialQueueName = "koding-social-prod"

webPort          = 3040
brokerPort       = 8010 + (version % 10)
sourceServerPort = 1300 + (version % 10)
dynConfig        = JSON.parse(fs.readFileSync("#{projectRoot}/config/.dynamic-config.json"))

module.exports = deepFreeze
  haproxy:
    webPort     : webPort
  aws           :
    key         : 'AKIAJSUVKX6PD254UGAA'
    secret      : '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'
  uri           :
    address     : "https://koding.com"
  projectRoot   : projectRoot
  version       : version
  webserver     :
    login       : 'prod-webserver'
    port        : dynConfig.webInternalPort
    clusterSize : 10
    queueName   : socialQueueName+'web'
    watch       : no
  sourceServer  :
    enabled     : yes
    port        : sourceServerPort
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
  goConfig:
    HomePrefix:   "/Users/"
    UseLVE:       true
  authWorker    :
    login       : 'prod-authworker'
    queueName   : socialQueueName+'auth'
    authResourceName: 'auth'
    numberOfWorkers: 2
    watch       : no
  cacheWorker   :
    login       : 'prod-social'
    watch       : no
    queueName   : socialQueueName+'cache'
    run         : yes
  social        :
    login       : 'prod-social'
    numberOfWorkers: 10
    watch       : no
    queueName   : socialQueueName
  feeder        :
    queueName   : "koding-feeder"
    exchangePrefix: "followable-"
    numberOfWorkers: 2
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
    staticFilesBaseUrl: 'https://koding.com'
    runtimeOptions:
      resourceName: socialQueueName
      suppressLogs: yes
      version   : version
      mainUri   : 'https://koding.com'
      broker    :
        sockJS  : "https://mq.koding.com:#{brokerPort}/subscribe"
      apiUri    : 'https://api.koding.com'
      # Is this correct?
      appsUri   : 'https://app.koding.com'
      sourceUri : "http://web-prod.in.koding.com:#{sourceServerPort}"
  mq            :
    host        : 'localhost'
    port        : 5672
    apiPort     : 55672
    login       : 'PROD-k5it50s4676pO9O'
    componentUser: "prod-<component>"
    password    : 'Dtxym6fRJXx4GJz'
    heartbeat   : 10
    vhost       : '/'
  broker        :
    port        : brokerPort
    certFile    : "/etc/nginx/ssl/server_new.crt"
    keyFile     : "/etc/nginx/ssl/server_new.key"
  kites:
    disconnectTimeout: 3e3
    vhost       : '/'
  email         :
    host        : 'koding.com'
    protocol    : 'https:'
    defaultFromAddress: 'hello@koding.com'
  emailWorker   :
    cronInstant : '*/10 * * * * *'
    cronDaily   : '0 10 0 * * *'
    run         : yes
    defaultRecepient : undefined
  guests        :
    # define this to limit the number of guset accounts
    # to be cleaned up per collection cycle.
    poolSize        : 1e4
    batchSize       : undefined
    cleanupCron     : '*/10 * * * * *'
  pidFile       : '/tmp/koding.server.pid'
  loggr:
    push: yes
    url: "http://post.loggr.net/1/logs/koding/events"
    apiKey: "eb65f620b72044118015d33b4177f805"
  librato:
    push: yes
    email: "devrim@koding.com"
    token: "3f79eeb972c201a6a8d3461d4dc5395d3a1423f4b7a2764ec140572e70a7bce0"
    interval: 60000

