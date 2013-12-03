__utils.extend __utils,

  getPaymentMethodTitle: (billing)->
    # for convenience, accept either the payment method, or the billing object
    { billing } = billing  if billing.billing?

    { cardFirstName, cardLastName, cardType, cardNumber } = billing

    """
    #{ cardFirstName } #{ cardLastName } (#{ cardType } #{ cardNumber })
    """

  botchedUrlRegExp: /(([a-zA-Z]+\:)?\/\/)+(\w+:\w+@)?([a-zA-Z\d.-]+\.[A-Za-z]{2,4})(:\d+)?(\/\S*)?/g

  webProtocolRegExp: /^((http(s)?\:)?\/\/)/

  proxifyUrl:(url="", options={})->

    options.width   or= -1
    options.height  or= -1

    if url is ""
      return "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="

    if options.width or options.height
      endpoint = "/resize"
    if options.crop
      endpoint = "/crop"
    return "https://i.embed.ly/1/display#{endpoint or ''}?grow=false&width=#{options.width}&height=#{options.height}&key=#{KD.config.embedly.apiKey}&url=#{encodeURIComponent url}"

  showMoreClickHandler:(event)->
    $trg = $(event.target)
    more = "span.collapsedtext a.more-link"
    less = "span.collapsedtext a.less-link"
    $trg.parent().addClass("show").removeClass("hide") if $trg.is(more)
    $trg.parent().removeClass("show").addClass("hide") if $trg.is(less)

  applyTextExpansions: (text, shorten)->
    return null unless text

    text = text.replace /&#10;/g, ' '

    # Expand URLs with intention to replace them after putShowMore
    {links,text} = @expandUrls text, yes

    text = __utils.putShowMore text if shorten

    # Reinsert URLs into text
    if links? then for link,i in links
      text = text.replace "[tempLink#{i}]", link

    text = @expandUsernames text
    return text
    # @expandWwwDotDomains @expandUrls @expandUsernames text

  expandWwwDotDomains: (text) ->
    return null unless text
    text.replace /(^|\s)(www\.[A-Za-z0-9-_]+.[A-Za-z0-9-_:%&\?\/.=]+)/g, (_, whitespace, www) ->
      "#{whitespace}<a href='http://#{www}' target='_blank'>#{www}</a>"

  expandUsernames: (text, excludeSelector) ->
    # excludeSelector is a jQuery selector

    # as a JQuery selector, e.g. "pre"
    # means that all @s in <pre> tags will not be expanded

    return null unless text

    # default case for regular text
    if not excludeSelector
      text.replace /\B\@([\w\-]+)/gim, (u) ->
        username = u.replace "@", ""
        u.link "/#{username}"
    # context-sensitive expansion
    else
      result = ""
      $(text).each (i, element) ->
        $element = $(element)
        elementCheck = $element.not excludeSelector
        parentCheck = $element.parents(excludeSelector).length is 0
        childrenCheck = $element.find(excludeSelector).length is 0
        if elementCheck and parentCheck and childrenCheck
          if $element.html()?
            replacedText =  $element.html().replace /\B\@([\w\-]+)/gim, (u) ->
              username = u.replace "@", ""
              u.link "/#{username}"
            $element.html replacedText
        result += $element.get(0).outerHTML or "" # in case there is a text-only element
      result

  expandTags: (text) ->
    return null unless text
    text.replace /[#]+[A-Za-z0-9-_]+/g, (t) ->
      tag = t.replace "#", ""
      "<a href='#!/topic/#{tag}' class='ttag'><span>#{tag}</span></a>"

  expandUrls: (text,replaceAndYieldLinks=no) ->
    return null unless text

    links = []
    linkCount = 0

    urlGrabber = ///
    (?!\s)                                                      # leading spaces
    ([a-zA-Z]+://)                                              # protocol
    (\w+:\w+@|[\w|\d]+@|)                                       # username:password@
    ((?:[a-zA-Z\d]+(?:-[a-zA-Z\d]+)*\.)*)                       # subdomains
    ([a-zA-Z\d]+(?:[a-zA-Z\d]|-(?=[a-zA-Z\d]))*[a-zA-Z\d]?)     # domain
    \.                                                          # dot
    ([a-zA-Z]{2,4})                                             # top-level-domain
    (:\d+|)                                                     # :port
    (/\S*|)                                                     # rest of url
    (?!\S)
    ///g


    # This will change the original string to either a fully replaced version
    # or a version with temporary replacement strings that will later be replaced
    # with the expanded html tags
    text = text.replace urlGrabber, (url) ->

      url = url.trim()
      originalUrl = url

      # remove protocol and trailing path
      visibleUrl = url.replace(/(ht|f)tp(s)?\:\/\//,"").replace(/\/.*/,"")
      checkForPostSlash = /.*(\/\/)+.*\/.+/.test originalUrl # test for // ... / ...

      if not /[A-Za-z]+:\/\//.test url

        # url has no protocol
        url = '//'+url

      # Just yield a placeholder string for replacement later on
      # this is needed if the text should get shortened, add expanded
      # string to array at corresponding index
      if replaceAndYieldLinks
        links.push "<a href='#{url}' data-original-url='#{originalUrl}' target='_blank' >#{visibleUrl}#{if checkForPostSlash then "/…" else ""}<span class='expanded-link'></span></a>"
        "[tempLink#{linkCount++}]"
      else
        # yield the replacement inline (good for non-shortened text)
        "<a href='#{url}' data-original-url='#{originalUrl}' target='_blank' >#{visibleUrl}#{if checkForPostSlash then "/…" else ""}<span class='expanded-link'></span></a>"

    if replaceAndYieldLinks
      {
        links
        text
      }
    else
      text

  putShowMore: (text, l = 500)->
    shortenedText = __utils.shortenText text,
      minLength : l
      maxLength : l + Math.floor(l/10)
      suffix    : ''

    # log "[#{text.length}:#{Encoder.htmlEncode(text).length}/#{shortenedText.length}:#{Encoder.htmlEncode(shortenedText).length}]"
    text = if Encoder.htmlEncode(text).length > Encoder.htmlEncode(shortenedText).length
      morePart = "<span class='collapsedtext hide'>"
      morePart += "<a href='#' class='more-link' title='Show more...'>Show more...</a>"
      morePart += Encoder.htmlEncode(text).substr Encoder.htmlEncode(shortenedText).length
      morePart += "<a href='#' class='less-link' title='Show less...'>...show less</a>"
      morePart += "</span>"
      Encoder.htmlEncode(shortenedText) + morePart
    else
      Encoder.htmlEncode shortenedText

  shortenText: do ->
    tryToShorten = (longText, optimalBreak = ' ', suffix)->
      unless ~ longText.indexOf optimalBreak then no
      else
        "#{longText.split(optimalBreak).slice(0, -1).join optimalBreak}#{suffix ? optimalBreak}"

    (longText, options={})->
      return unless longText
      minLength = options.minLength or 450
      maxLength = options.maxLength or 600
      suffix    = options.suffix     ? '...'

      longTextLength  = longText.length

      tempText = longText.slice 0, maxLength
      lastClosingTag = tempText.lastIndexOf "]"
      lastOpeningTag = tempText.lastIndexOf "["

      if lastOpeningTag <= lastClosingTag
        finalMaxLength = maxLength
      else
        finalMaxLength = lastOpeningTag

      return longText if longText.length < minLength or longText.length < maxLength

      longText = longText.substr 0, finalMaxLength

      # prefer to end the teaser at the end of a sentence (a period).
      # failing that prefer to end the teaser at the end of a word (a space).
      candidate = tryToShorten(longText, '. ', suffix) or tryToShorten longText, ' ', suffix

      return \
        if candidate?.length > minLength then candidate
        else longText

  getMonthOptions : ->
    ((if i > 9 then { title : "#{i}", value : i} else { title : "0#{i}", value : i}) for i in [1..12])

  getYearOptions  : (min = 1900,max = Date::getFullYear())->
    ({ title : "#{i}", value : i} for i in [min..max])

  getFullnameFromAccount:(account, justName=no)->
    account or= KD.whoami()
    if account.type is 'unregistered'
      name = "a guest"
    else if justName
      name = account.profile.firstName
    else
      name = "#{account.profile.firstName} #{account.profile.lastName}"
    return Encoder.htmlEncode name or 'a Koding user'

  getNameFromFullname :(fullname)->
    fullname.split(' ')[0]

  notifyAndEmailVMTurnOnFailureToSysAdmin: (vmName, reason)->
    if window.localStorage.notifiedSysAdminOfVMFailureTime
      if parseInt(window.localStorage.notifiedSysAdminOfVMFailureTime, 10)+(1000*60*60)>Date.now()
        return

    window.localStorage.notifiedSysAdminOfVMFailureTime = Date.now()

    new KDNotificationView
      title:"Sorry, your vm failed to turn on. An email has been sent to a sysadmin."

    KD.whoami().sendEmailVMTurnOnFailureToSysAdmin vmName, reason

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
        return __utils.generatePassword length, memorable, pattern, prefix

      return __utils.generatePassword length, memorable, pattern, "" + prefix + chr

  # Version Compare
  # https://github.com/balupton/bal-util/blob/master/src/lib/compare.coffee
  # http://phpjs.org/functions/version_compare
  # MIT Licensed http://phpjs.org/pages/license
  versionCompare: (v1,operator,v2) ->
    i  = x = compare = 0
    vm =
      dev   : -6
      alpha : -5
      a     : -5
      beta  : -4
      b     : -4
      RC    : -3
      rc    : -3
      '#'   : -2
      p     : -1
      pl    : -1

    prepVersion = (v) ->
      v = ('' + v).replace(/[_\-+]/g, '.')
      v = v.replace(/([^.\d]+)/g, '.$1.').replace(/\.{2,}/g, '.')
      if !v.length then [-8]
      else v.split('.')

    numVersion = (v) ->
      if !v then 0
      else
        if isNaN(v) then vm[v] or -7
        else parseInt(v, 10)

    v1 = prepVersion(v1)
    v2 = prepVersion(v2)
    x  = Math.max(v1.length, v2.length)

    for i in [0..x]
      if (v1[i] == v2[i])
        continue

      v1[i] = numVersion(v1[i])
      v2[i] = numVersion(v2[i])

      if (v1[i] < v2[i])
        compare = -1
        break
      else if v1[i] > v2[i]
        compare = 1
        break

    return compare unless operator
    return switch operator
      when '>', 'gt'
        compare > 0
      when '>=', 'ge'
        compare >= 0
      when '<=', 'le'
        compare <= 0
      when '==', '=', 'eq', 'is'
        compare == 0
      when '<>', '!=', 'ne', 'isnt'
        compare != 0
      when '', '<', 'lt'
        compare < 0
      else
        null

  getDummyName:->
    u  = KD.utils
    gr = u.getRandomNumber
    gp = u.generatePassword
    gp(gr(10), yes)

  registerDummyUser:->

    return if location.hostname isnt "localhost"

    u  = KD.utils

    uniqueness = (Date.now()+"").slice(6)
    formData   =
      agree           : "on"
      email           : "sinanyasar+#{uniqueness}@gmail.com"
      firstName       : u.getDummyName()
      lastName        : u.getDummyName()
      inviteCode      : "twitterfriends"
      password        : "123123123"
      passwordConfirm : "123123123"
      username        : uniqueness

    KD.remote.api.JUser.register formData, => location.reload yes

  postDummyStatusUpdate:->

    return if location.hostname isnt "localhost"

    body  = KD.utils.generatePassword(KD.utils.getRandomNumber(50), yes) + ' ' + dateFormat(Date.now(), "dddd, mmmm dS, yyyy, h:MM:ss TT")
    if KD.config.entryPoint?.type is 'group' and KD.config.entryPoint?.slug
      group = KD.config.entryPoint.slug
    else
      group = 'koding' # KD.defaultSlug

    KD.remote.api.JStatusUpdate.create {body, group}, (err,reply)=>
      unless err
        KD.getSingleton("appManager").tell 'Activity', 'ownActivityArrived', reply
      else
        new KDNotificationView type : "mini", title : "There was an error, try again later!"

  startRollbar: ->
    @replaceFromTempStorage "_rollbar"

  stopRollbar: ->
    @storeToTempStorage "_rollbar", window._rollbar
    window._rollbar = {push:->}

  startMixpanel: ->
    @replaceFromTempStorage "mixpanel"

  stopMixpanel: ->
    @storeToTempStorage "mixpanel", window.mixpanel
    window.mixpanel = {track:->}

  replaceFromTempStorage: (name)->
    if item = @tempStorage[name]
      window[item] = item
    else
      log "no #{name} in mainController temp storage"

  storeToTempStorage: (name, item)-> @tempStorage[name] = item

  tempStorage:-> KD.getSingleton("mainController").tempStorage

  applyGradient: (view, color1, color2) ->
    rules = [
      "-moz-linear-gradient(100% 100% 90deg, #{color2}, #{color1})"
      "-webkit-gradient(linear, 0% 0%, 0% 100%, from(#{color1}), to(#{color2}))"
    ]
    view.setCss "backgroundImage", rule for rule in rules

  getAppIcon:(appManifest)->
    {authorNick, name, version, icns} = appManifest

    resourceRoot = "#{KD.appsUri}/#{authorNick}/#{name}/#{version}/"

    if appManifest.devMode # TODO: change url to https when vm urls are ready for it
      resourceRoot = "http://#{KD.getSingleton('vmController').defaultVm}/.applications/#{__utils.slugify name}/"

    image  = if name is "Ace" then "icn-ace" else "default.app.thumb"
    thumb  = "#{KD.apiUri}/images/#{image}.png"

    for size in [64, 128, 160, 256, 512]
      if icns and icns[String size]
        thumb = "#{resourceRoot}/#{icns[String size]}"
        break

    img = new KDCustomHTMLView
      tagName     : "img"
      bind        : "error"
      error       : ->
        @getElement().setAttribute "src", "/images/default.app.thumb.png"
      attributes  :
        src       : thumb

    return img


  compileCoffeeOnClient: (coffeeCode, callback = noop) ->
    require ["//cdnjs.cloudflare.com/ajax/libs/coffee-script/1.6.3/coffee-script.min.js"], (coffeeCompiler) ->
      callback coffeeCompiler.eval coffeeCode

  showSaveDialog: (container, callback = noop, options = {}) ->
    container.addSubView dialog = new KDDialogView
      cssClass      : KD.utils.curry "save-as-dialog", options.cssClass
      duration      : 200
      topOffset     : 0
      overlay       : yes
      height        : "auto"
      buttons       :
        Save        :
          style     : "modal-clean-gray"
          callback  : => callback input, finderController, dialog
        Cancel      :
          style     : "modal-cancel"
          callback  : =>
            finderController.stopAllWatchers()
            delete finderController
            finderController.destroy()
            dialog.destroy()

    dialog.addSubView wrapper = new KDView
      cssClass : "kddialog-wrapper"

    wrapper.addSubView form = new KDFormView

    form.addSubView label = new KDLabelView
      title : options.inputLabelTitle or "Filename:"

    form.addSubView input = new KDInputView
      label        : label
      defaultValue : options.inputDefaultValue or ""

    form.addSubView labelFinder = new KDLabelView
      title : options.finderLabel or "Select a folder:"

    dialog.show()
    input.setFocus()

    finderController    = new NFinderController
      nodeIdPath        : "path"
      nodeParentIdPath  : "parentPath"
      foldersOnly       : yes
      contextMenu       : no
      loadFilesOnInit   : yes

    finder = finderController.getView()
    finderController.reset()

    form.addSubView finderWrapper = new KDView cssClass : "save-as-dialog save-file-container", null
    finderWrapper.addSubView finder
    finderWrapper.setHeight 200

  # TODO: Not totally sure what this is supposed to do, but I put it here
  #       to bypass awful hacks by Arvid Kahl:
  getEmbedType: (type) ->
    switch type
      when 'audio', 'xml', 'json', 'ppt', 'rss', 'atom'
        return 'object'

      # this is usually just a single image
      when 'photo','image'
        return 'image'

      # rich is a html object for things like twitter posts
      # link is fallback for things that may or may not have any kind of preview
      # or are links explicitly
      # also captures 'rich content' and makes regular links from that data
      when 'link', 'html'
        return 'link'

      # embedly supports many error types. we could display those to the user
      when 'error'
        log 'Embedding error ', data.error_type, data.error_message
        return 'error'

      else
        log "Unhandled content type '#{type}'"
        return 'error'

  formatMoney: accounting.formatMoney
