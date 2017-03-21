traverse  = require 'traverse'

module.exports.create = (KONFIG, options = {}) ->
  env = ''

  add = (name, value) ->
    env += "declare -p #{name} &> /dev/null || export #{name}=\"#{value}\"\n"

  traverse.paths(KONFIG).forEach (path) ->
    node = traverse.get KONFIG, path
    return  if typeof node is 'object'
    add "KONFIG_#{path.join('_').replace(/\./g, "_")}".toUpperCase(), node

  add 'ENV_JSON_FILE', '$(dirname ${BASH_SOURCE[0]})/$(basename ${BASH_SOURCE[0]} .sh).json'
  add 'KONFIG_JSON', '$(cat $ENV_JSON_FILE)'

  add 'KITE_HOME', '$KONFIG_KITEHOME'
  add 'GOPATH', '$KONFIG_PROJECTROOT/go'
  add 'GOBIN', '$GOPATH/bin'

  return env
