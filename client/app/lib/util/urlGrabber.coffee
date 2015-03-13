_         = require 'underscore'
validator = require 'validator'

module.exports = (str) ->

  words = str.split(' ')
  urls  = _.uniq (word for word in words when validator.isURL word) or []

  return urls