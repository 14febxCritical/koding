class ActivitySharePopup extends SharePopup

  constructor: (options={}, data)->

    options.cssClass        = "share-popup"
    options.shortenText     = true
    options.twitter         = @getTwitterOptions options
    options.newTab          = @getNewTabOptions options

    super options, data

  getTwitterOptions:(options)->
    data = options.delegate.getData()
    {tags} = data
    if tags
      hashTags  = ("##{tag.slug}"  for tag in tags when tag?.slug)
      hashTags  = _.unique(hashTags).join " "
      hashTags += " "
    else
      hashTags = ''

    {title, body} = data
    itemText  = KD.utils.shortenText title or body, maxLength: 100, minLength: 100
    shareText = "#{itemText} #{hashTags}- #{options.url}"

    return twitter =
      enabled : true
      text    : shareText

  getNewTabOptions:(options)->
    return { enabled : true, url : options.url }

class ActivityActionsView extends KDView

  contextMenu = null
  constructor:->
    super

    activity = @getData()

    @commentLink  = new ActivityActionLink
      partial : "Comment"

    @commentCount = new ActivityCommentCount
      tooltip     :
        title     : "Show all"
      click       : (event) =>
        KD.utils.stopDOMEvent event
        @getDelegate().emit "CommentCountClicked", this
    , activity

    @shareLink = new ActivityActionLink
      partial  : "Share"
      click    : (event) =>
        KD.utils.stopDOMEvent event
        data = @getData()
        if data?.group? and data.group isnt "koding"
          shareUrl = "#{KD.config.mainUri}/#{data.group}/Activity/#{data.slug}"
        else
          shareUrl      = "#{KD.config.mainUri}/Activity/#{data.slug}"
        contextMenu   = new KDContextMenu
          cssClass    : "activity-share-popup"
          type        : "activity-share"
          delegate    : this
          x           : @shareLink.getX() + 25
          y           : @shareLink.getY() - 7
          menuMaxWidth: 400
          menuMinWidth: 192
          lazyLoad    : yes
        , customView  : new ActivitySharePopup delegate: this, url: shareUrl

        KD.mixpanel "Activity share, click"

    @likeView = new ActivityLikeView
      cssClass           : "logged-in action-container"
      useTitle           : yes
      checkIfLikedBefore : yes
    , activity

    @loader = new KDLoaderView
      cssClass      : 'action-container'
      size          :
        width       : 16
      loaderOptions :
        color       : '#6B727B'

    # unless KD.isLoggedIn()
    #   @commentLink.setTooltip title: "Login required"
    #   @likeView.likeLink.setTooltip title: "Login required"
    #   KD.getSingleton("mainController").on "accountChanged.to.loggedIn", =>
    #     delete @likeView.likeLink.tooltip
    #     delete @commentLink.tooltip

  viewAppended:->

    @setClass "activity-actions"
    @setTemplate @pistachio()
    @template.update()
    @attachListeners()
    @loader.hide()

  pistachio:->

    """
    {{> @likeView}}
    <span class='logged-in action-container'>
      {{> @commentLink}}{{> @commentCount}}
    </span>
    <span class='optional action-container'>
      {{> @shareLink}}
    </span>
    {{> @loader}}
    """

  attachListeners:->

    activity    = @getData()
    commentList = @getDelegate()

    commentList.on 'BackgroundActivityStarted',  @loader.bound 'show'
    commentList.on 'BackgroundActivityFinished', @loader.bound 'hide'

    @commentLink.on "click", (event)=>
      @utils.stopDOMEvent event
      commentList.emit "CommentLinkReceivedClick", event, this

class ActivityActionLink extends KDCustomHTMLView
  constructor:(options,data)->
    options = $.extend
      tagName   : "a"
      cssClass  : "action-link"
      attributes:
        href    : "#"
    , options
    super options,data

class ActivityCountLink extends KDCustomHTMLView

  constructor:(options,data)->

    options = $.extend
      tagName   : "a"
      cssClass  : "count"
      attributes:
        href    : "#"
    , options

    super options, data


  render: ->

    super

    @setCount()


  viewAppended: ->

    super

    @setCount()


class ActivityLikeCount extends ActivityCountLink

  constructor: (options, data) ->

    super options, data

    @oldCount = (data.meta.likes or 0) or 0


  setCount: ->

    {meta} = @getData()
    likes = (meta?.likes) or 0

    if likes isnt @oldCount
      @emit "countChanged", likes

    @oldCount = likes

    if likes
    then @show()
    else @hide()


  pistachio: ->

    "{{ #(meta.likes)}}"


class ActivityCommentCount extends ActivityCountLink

  setCount: ->

    {repliesCount} = @getData()

    if repliesCount
    then @show()
    else @hide()

    @emit "countChanged", repliesCount


  pistachio: ->

    "{{ #(repliesCount)}}"
