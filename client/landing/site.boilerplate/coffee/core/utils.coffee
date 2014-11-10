utils.extend utils,

  ###
  password-generator
  Copyright(c) 2011 Bermi Ferrer <bermi@bermilabs.com>
  MIT Licensed
  ###
  generatePassword: do ->

    letter = /[a-zA-Z]$/;
    vowel = /[aeiouAEIOU]$/;
    consonant = /[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]$/;

    (length = 10, memorable = yes, pattern = /\w/, prefix = '')->

      return prefix if prefix.length >= length

      if memorable
        pattern = if consonant.test(prefix) then vowel else consonant

      n   = (Math.floor(Math.random() * 100) % 94) + 33
      chr = String.fromCharCode(n)
      chr = chr.toLowerCase() if memorable

      unless pattern.test chr
        return utils.generatePassword length, memorable, pattern, prefix

      return utils.generatePassword length, memorable, pattern, "" + prefix + chr

  getDummyName:->
    u  = KD.utils
    gr = u.getRandomNumber
    gp = u.generatePassword
    gp(gr(10), yes)

  generateDummyUserData:->

    u  = KD.utils

    uniqueness = (Date.now()+"").slice(6)
    return formData   =
      agree           : "on"
      email           : "sinanyasar+#{uniqueness}@gmail.com"
      firstName       : u.getDummyName()
      lastName        : u.getDummyName()
      # inviteCode      : "twitterfriends"
      password        : "123123123"
      passwordConfirm : "123123123"
      username        : uniqueness


  getLocationInfo: do (queue=[])->

    ip      = null
    country = null
    region  = null

    fail = ->

      for cb in queue
        cb { message: "Failed to fetch IP info." }

      queue = []

    (callback = noop)->

      if ip? and country? and region?
        callback null, { ip, country, region }
        return

      return  if (queue.push callback) > 1

      KD.utils.wait 5000, fail

      $.getJSON '//freegeoip.net/json/?callback=?', (data, status)->

        if status is "success"

          { ip, country_code, region_code } = data

          country = country_code
          region  = region_code

          for cb in queue
            cb null, { ip, country, region }

          queue = []

        else do fail

      .fail -> do fail


  registerDummyUser:->

    return if location.hostname is "koding.com"

    u  = KD.utils

    KD.remote.api.JUser.register u.generateDummyUserData(), => location.reload yes



  # Chrome apps open links in a new browser window. OAuth authentication
  # relies on `window.opener` to be present to communicate back to the
  # parent window, which isn't available in a chrome app. Therefore, we
  # disable/change oauth behavior based on this flag: SA.
  oauthEnabled: -> window.name isnt "chromeapp"