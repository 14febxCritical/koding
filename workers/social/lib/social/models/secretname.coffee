{ Model } = require 'bongo'

module.exports = class JSecretName extends Model

  @set
    softDelete    : no
    sharedEvents  :
      instance    : []
      static      : []

  # TODO: the below should be made a bit more secure:
  @setSchema
    name          : String
    secretName    :
      type        : String
      default     : require 'hat'
    oldSecretName : String


