class Ping extends KDObject
  [NOTSTARTED, WAITING, SUCCESS, FAILED] = [1..4]

  constructor: (item, name, options={}) ->
    super options

    @item = item
    @name = name
    @identifier = options.identifier or Date.now()
    @status = NOTSTARTED

  run: ->
    @status = WAITING
    @startTime = Date.now()
    @setPingTimeout()
    @item.ping(@finish.bind(this))

  setPingTimeout: ->
    @pingTimeout = setTimeout =>
      @status = FAILED
      @emit "failed", @item, @name
    , 5000

  finish: ->
    @status = SUCCESS
    @finishTime = Date.now()
    clearTimeout @pingTimeout
    @pingTimeout = null
    @emit "finish", @item, @name

  getResponseTime: ->
    status = switch @status
      when NOTSTARTED
        "not started"
      when FAILED
        "failed"
      when SUCCESS
        @finishTime - @startTime
      when "WAITING"
        "waiting"

    return status

class MonitorItems extends KDObject
  constructor: (options={}) ->
    super @options
    @items = {}
    @registerSingleton "monitorItems", this

  register: (items) ->
    for name, item of items
      @items[name] = item

  getItems: ->
    @items

class MonitorStatus extends KDObject
  constructor: (items, options={}) ->
    super @options

    @itemsToMonitor = {}
    @reset()

    @copyItemsToMonitor(items)
    @setupListerners()

  copyItemsToMonitor: (items) ->
    for name, item of items
      @itemsToMonitor[name] = new Ping item, name

  setupListerners: ->
    @on "pingFailed", (item, name) ->
      @failedPings.push name
      @emit "pingDone", item, name

    @on "pingDone", (item, name) ->
      @finishedPings.push name
      if _.size(@finishedPings) == _.size(@itemsToMonitor)
        @emit "allDone"

    @on "allDone", ->
      @emitStatus()
      @printReport()
      @reset()

    @on "webtermDown", (channel) ->
      @emit "onlyChannelDown", "webterm"

    @on "sharedHostingDown", (channel) ->
      @emit "onlyChannelDown", "sharedHosting"

    @on "internetDown", ->
      status = KD.getSingleton "status"
      status.internetDown()

  notify: (reason) ->
    return  unless @showNotifications

    notifications =
      internetUp : "All systems go!"
      internetDown: "Your internet is down."
      kodingDown: "Koding is down."
      kitesDown: "Kites are down."
      sharedHostingDown: "SharedHosting is down."
      webtermDown: "Webterm is down."
      bongoDown: "Bongo is down"
      brokerDown: "Broker is Down."
      undefined: "Sorry, something went wrong."

    msg = notifications[reason] or notifications["undefined"]

    notification = new KDNotificationView
      title     : "<span></span>#{msg}"
      type      : "tray"
      cssClass  : "mini realtime"
      duration  : 3303
      click     : noop

  reset: ->
    @finishedPings = []
    @failedPings = []

  emitStatus: ->
    if _.size(@failedPings) is 0
      @internetUp()
      @notify "internetUp"
    else
      @deductReasonForFailure()

  deductReasonForFailure: ->
    reasons = {}
    reasons.internetDown      = ["bongo", "broker", "external"]
    reasons.kodingDown        = ["bongo", "broker"]
    reasons.kitesDown         = ["sharedHosting", "webterm"]
    reasons.brokerDown        = ["broker"]
    reasons.bongoDown         = ["bongo"]
    reasons.sharedHostingDown = ["sharedHosting"]
    reasons.webtermDown       = ["webterm"]

    for reason, items of reasons
      intersection = _.intersection items, @failedPings
      if _.size(intersection) is _.size(items)
        @emit reason, _.first(@failedPings)
        @notify reason
        log reason
        return reason

  internetUp: ->
    log  "all's well on western front"
    @emit 'internetUp'

  printReport: ->
    for name, item of @itemsToMonitor
      log name, item.getResponseTime()

  run: ->
    for name, item of @itemsToMonitor
      item.once "finish", (i, n) =>
        @emit "pingDone", i, n
      item.once "failed", (i, n) =>
        @emit "pingFailed", i, n
      item.run()

class ExternalPing extends KDObject
  constructor: (@url) -> super

  ping: (callback) ->
    @callback = callback
    KD.externalPong = @pong.bind(this)
    $.ajax
      url : @url+"?callback"+KD.externalPong
      timeout: 5000
      dataType: "jsonp"
      error : ->

  pong: -> @callback()

do ->
  url = "https://s3.amazonaws.com/koding-ping/ping.json"
  external = new ExternalPing url

  monitorItems = new MonitorItems
  monitorItems.register {external}

  KD.troubleshoot = (showNotifications=true)->
    monitorItems = KD.getSingleton("monitorItems").items
    monitor = new MonitorStatus monitorItems
    monitor.showNotifications = showNotifications
    monitor.run()

  window.jsonp = ->
    KD.externalPong()

  brokerInterval  = null
  failureCallback = null
  lastPong        = null

  # use broker ping to determine internet connection
  pingBrokerOnInterval = ->
    brokerInterval = setInterval ->
      clearTimeout failureCallback
      failureCallback = null

      brokerPong = ->
        # account for people disconnecting at night, then reconnecting in the
        # morning; if reconnection happens before failureCallback is trigged,
        # we won't know that disconnection has happened.
        if lastPong && (Date.now() - lastPong) > 30*1000
          log "lastPong too long ago, possible computer sleep; disconnecting"
          KD.logToMixpanel "computer woke up from sleep"

          status = KD.getSingleton "status"
          status.disconnect
            reason:"internetDownForLongTime"
            notify:no

        clearTimeout failureCallback
        failureCallback = null
        lastPong = Date.now()

      failureCallback = setTimeout ->
        log 'broker ping failed, running troubleshoot', failureCallback
        KD.troubleshoot(false)
      , 3000

      KD.remote.mq.ping -> brokerPong()

    , 5000

  KD.remote.on 'connected', ->
    pingBrokerOnInterval()
    log 'connected, starting broker ping', brokerInterval

  KD.remote.on 'disconnected', ->
    return unless brokerInterval?

    log 'disconnected, stopping broker ping'

    clearInterval brokerInterval
    brokerInterval = null
