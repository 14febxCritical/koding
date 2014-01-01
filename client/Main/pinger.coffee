class Pinger extends KDObject
  constructor: (options, data) ->
    super options, data

  reset:->
    clearTimeout @unresponsiveTimeoutId  if @unresponsiveTimeoutId?
    clearTimeout @pingTimeoutId          if @pingTimeoutId?

    delete @unresponsiveTimeoutId
    delete @pingTimeoutId

  handleChannelPublish: ->
    @reset()

    @unresponsiveTimeoutId = setTimeout =>
      @emit "possibleUnresponsive"
    , 5000

  handleMessageArrived: ->
    @reset()

    @unresponded = 0
    @lastPong    = Date.now()

    @pingTimeoutId = setTimeout =>
      @ping()
    , 10000

  handleSuspectChannel: ->
    @unresponded ||= 0
    log "broker possibleUnresponsive: #{@unresponded} times"
    @unresponded++
    if @unresponded > 1 then @emit 'unresponsive' else @run()

  setStartPinging: -> @stopPinging = no

  setStopPinging: -> @stopPinging = yes
