{argv} = require 'optimist'

module.exports = require './' + argv.c ? 'config-prod'