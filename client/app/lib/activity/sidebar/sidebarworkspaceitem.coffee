kd = require 'kd'
KDListItemView = kd.ListItemView
KDCustomHTMLView = kd.CustomHTMLView
JView = require 'app/jview'
CustomLinkView = require 'app/customlinkview'
groupifyLink = require 'app/util/groupifyLink'
WorkspaceSettingsPopup = require 'app/workspacesettingspopup'


module.exports = class SidebarWorkspaceItem extends KDListItemView

  JView.mixin @prototype

  constructor: (options = {}, data) ->

    options.cssClass = 'kdlistitemview-main-nav workspace'

    super options, data # machine data is `options.machine`, workspace data is `data`

    {machine} = options
    workspace = data # to make it more sense in the following lines.
    path      = "/IDE/#{machine.slug or machine.label}/#{workspace.slug}"
    title     = workspace.name

    unless machine.isMine()
      if machine.isPermanent()
        kd.log 'update shared ws url here'
      else
        path = "/IDE/#{workspace.channelId}"

    href   = groupifyLink path
    @title = new CustomLinkView { href, title }

    @unreadCount = new KDCustomHTMLView
      tagName    : 'cite'
      cssClass   : 'count hidden'

    iconOptions = {}

    unless workspace.isDefault
      iconOptions =
        tagName   : 'span'
        cssClass  : 'ws-settings-icon'
        click     : @bound 'showSettingsPopup'

    @settingsIcon = new KDCustomHTMLView iconOptions


  showSettingsPopup: ->

    { x, y, w } = @getBounds()
    top         = Math.max y - 38, 0
    left        = x + w + 16
    position    = { top, left }

    settingsPopup = new WorkspaceSettingsPopup { position, delegate: this }
    settingsPopup.once 'WorkspaceDeleted', (wsId) =>
      @emit 'WorkspaceDeleted', wsId


  setUnreadCount: (unreadCount = 0) ->

    @count = unreadCount

    if unreadCount is 0
      @unreadCount.hide()
      @unsetClass 'unread'
    else
      @unreadCount.updatePartial unreadCount
      @unreadCount.show()
      @setClass 'unread'


  pistachio: ->
    """
      <figure></figure>
      {{> @title}}
      {{> @settingsIcon}}
      {{> @unreadCount}}
    """

