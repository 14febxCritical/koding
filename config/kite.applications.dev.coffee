nodePath = require 'path'

module.exports =
  name              : "applications"
  pidPath           : "/var/run/node/Applications.pid"
  logFile           : "/var/log/node/Applications.log"
  amqp                  :
    host                : 'web-dev.in.koding.com'
    login               : 'kite-sharedHosting'
    password            : 's486auEkPzvUjYfeFTMQ'
    heartbeat           : 10
  apiUri            : 'https://dev-api.koding.com/1.0'
  usersPath         : '/Users/'
  vhostDir          : 'Sites'
  defaultDomain     : 'koding.com'
  minAllowedUid     : 600 # minumum allowed UID for OS commands
  debugApi          : true
