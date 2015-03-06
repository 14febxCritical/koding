Encoder  = require 'htmlencode'
kd       = require 'kd'
KDObject = kd.Object
remote   = require('./remote').getInstance()

module.exports = class PageTitleController extends KDObject

  constructor: ->

    super

    @defaultTitle = global.document.title
    @focused      = yes
    @blinker      = null
    @count        = 0

    { notificationController, windowController } = kd.singletons
    notificationController.on 'MessageAddedToChannel', @bound 'processNotification'

    windowController.addFocusListener (focused) => @resetCount()  if @focused = focused


  processNotification: (notification) ->

    return  if @focused

    { socialapi }        = kd.singletons
    { id, typeConstant } = notification.channelMessage

    return  if typeConstant isnt 'privatemessage'

    socialapi.message.byId {id}, (err, message) =>
      id              = message.account._id
      constructorName = message.account.constructorName
      remote.cacheable constructorName, id, (err, account) =>
        @blink "#{account.profile.nickname} messaged you!"

    @count++
    @update "(#{@count}) #{@getAppTitle()}"


  blink: (title) ->

    kd.utils.killRepeat @blinker  if @blinker
    defaultState = on
    @blinker = kd.utils.repeat 5000, =>
      unless defaultState
      then @update "(#{@count}) #{@getAppTitle()}"
      else @update title
      defaultState = !defaultState


  resetCount: ->

    @count = 0
    kd.utils.killRepeat @blinker  if @blinker
    @update @getAppTitle()


  update: (title) -> global.document.title = " #{Encoder.htmlDecode title}"

  reset: -> @update @defaultTitle

  get: -> return global.document.title or ""

  getRaw: -> return @get().replace /\([0-9]+\)\s(.*)/, '$1'

  getAppTitle: -> return kd.singletons.appManager.getFrontApp()?.options.name or 'Koding'