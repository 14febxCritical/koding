class ActivityActionsView extends KDView

  constructor:->
    super

    activity = @getData()

    @commentLink  = new ActivityActionLink
      partial : "Comment"

    @commentCount = new ActivityCommentCount
      tooltip     :
        title     : "Show all"
      click       : (event)=>
        # event.preventDefault()
        @getDelegate().emit "CommentCountClicked", @
    , activity

    @shareLink    = new ActivityActionLink
      partial     : "Share"
      tooltip     :
        title     : "Coming Soon"
      click:(event)=>
        event.preventDefault()

    @likeView     = new LikeView {checkIfLikedBefore: no}, activity
    @loader       = new KDLoaderView size : width : 14

    unless KD.isLoggedIn()
      @commentLink.setTooltip title: "Login required"
      @likeView.likeLink.setTooltip title: "Login required"
      KD.singletons.mainController.on "accountChanged.to.loggedIn", =>
        delete @likeView.likeLink.tooltip
        delete @commentLink.tooltip
        @attachListeners()

  viewAppended:->

    @setClass "activity-actions"
    @setTemplate @pistachio()
    @template.update()
    @attachListeners()
    @loader.hide()

  pistachio:->

    """
    {{> @loader}}
    {{> @commentLink}}{{> @commentCount}} ·
    <span class='optional'>
    {{> @shareLink}} ·
    </span>
    {{> @likeView}}
    """

  attachListeners:->

    activity    = @getData()
    commentList = @getDelegate()

    events =
      BackgroundActivityStarted  : 'show'
      BackgroundActivityFinished : 'hide'

    for ev, func of events
      commentList.off ev
      commentList.on ev, @loader.bound func

    if KD.isLoggedIn() then @commentLink.on "click", (event)=>
      commentList.emit "CommentLinkReceivedClick", event, @

class ActivityActionLink extends KDCustomHTMLView
  constructor:(options,data)->
    options = $.extend
      tagName   : "a"
      cssClass  : "action-link"
      attributes:
        href    : "#"
      partial   : "Like"
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
    super options,data

  render:->
    super
    @setCount @getData()

  viewAppended:->
    @setTemplate @pistachio()
    @template.update()
    activity = @getData()
    @setCount activity

  pistachio:-> ""

class ActivityLikeCount extends ActivityCountLink

  @oldCount = 0

  setCount:(activity)->
    if activity.meta.likes isnt @oldCount
      @emit "countChanged", activity.meta.likes
    @oldCount = activity.meta.likes
    if activity.meta.likes is 0 then @hide() else @show()

  pistachio:-> "{{ #(meta.likes)}}"

class ActivityCommentCount extends ActivityCountLink

  setCount:(activity)->
    if activity.repliesCount is 0 then @hide() else @show()
    @emit "countChanged", activity.repliesCount

  pistachio:-> "{{ #(repliesCount)}}"

class ActivityOpinionCount extends ActivityCountLink

  setCount:(activity)->
    if activity.opinionCount is 0 then @hide() else @show()
    @emit "countChanged", activity.opinionCount

  pistachio:-> "{{ #(opinionCount)}}"
