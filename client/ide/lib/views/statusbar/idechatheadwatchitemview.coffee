kd = require 'kd'
KDCustomHTMLView = kd.CustomHTMLView
KodingSwitch = require 'app/commonviews/kodingswitch'
CustomLinkView = require 'app/customlinkview'
module.exports = class IDEChatHeadWatchItemView extends KDCustomHTMLView

  constructor: (options = {}, data) ->

    options.partial ?= 'Watch'

    super options, data

    { delegate, isWatching } = @getOptions()

    @addSubView new KodingSwitch
      cssClass     : 'tiny'
      defaultValue : isWatching
      callback     : delegate.bound 'setWatchState'

    @addSubView new CustomLinkView
      title        : ''
      cssClass     : 'info'
      href         : 'http://learn.koding.com/guides/collaboration/#what-does-quot-watch-quot-mode-mean-'
      target       : '_blank'
