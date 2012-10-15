fs = require 'fs'
nodePath = require 'path'

deepFreeze = require 'koding-deep-freeze'

version = fs.readFileSync nodePath.join(__dirname, '../.revision'), 'utf-8'

# STAGING
mongo = 'beta_koding_user:lkalkslakslaksla1230000@localhost:27017/beta_koding?auto_reconnect'
#mongo = 'koding_stage_user:dkslkds84ddj@localhost:38017/koding_stage?auto_reconnect'

module.exports = deepFreeze
#  basicAuth     :
#    username    : 'koding'
#    password    : '314159'
  monit         :
    webCake     : '/var/run/node/webCake.pid'
    kiteCake    : '/var/run/node/kiteCake.pid'
  projectRoot   : nodePath.join __dirname, '..'
  version       : version
  webPort       : [3020..3021]
  mongo         : mongo
  runBroker     : no
  runGoBroker   : yes
  configureBroker: no
  buildClient   : no
  social        :
    numberOfWorkers: 4
  client        :
    version     : version
    minify      : yes
    js          : "./website/js/kd.#{version}.js"
    css         : "./website/css/kd.#{version}.css"
    indexMaster : "./client/index-master.html"
    index       : "./website/index.html"
    closureCompilerPath: "./builders/closure/compiler.jar"
    includesFile: '../CakefileIncludes.coffee'
    useStaticFileServer: no
    staticFilesBaseUrl: 'https://api.koding.com'
    runtimeOptions:
      suppressLogs: yes
      version   : version
      mainUri   : 'https://koding.com'
      broker    :
        apiKey  : 'a6f121a130a44c7f5325'
        sockJS  : 'https://mq.koding.com/subscribe'
        auth    : 'https://koding.com/auth'
        vhost   : '/'
      apiUri    : 'https://api.koding.com'
      appsUri   : 'https://app.koding.com'
      env       : 'beta'
  mq            :
    host        : 'localhost'
    login       : 'test'
    password    : 'test'
    vhost       : '/'
    pidFile     : '/var/run/broker.pid'
  kites:
    disconnectTimeout: 3e3
  email         :
    host        : 'koding.com'
    protocol    : 'https:'
    defaultFromAddress: 'hello@koding.com'
  guests:
     # define this to limit the number of guset accounts
     # to be cleaned up per collection cycle.
    batchSize   : undefined
    cleanupCron : '*/10 * * * * *'
    poolSize    : 1e4
  logger        :
    mq          :
      host      : 'localhost'
      login     : 'stage'
      password  : '#[85_[*zh7%4;4l6T]F!'
      vhost     : 'stage-logs'
  pidFile       : '/tmp/koding.server.pid'
