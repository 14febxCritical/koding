class CommentViewHeader extends JView

  constructor: (options = {}, data) ->

    options.cssClass          = KD.utils.curry "show-more-comments in", options.cssClass
    options.maxCommentToShow ?= 3

    super options, data

    {@maxCount}  = options
    @oldCount    = data.repliesCount
    @newCount    = 0
    @onListCount = if data.repliesCount > @maxCommentToShow then @maxCommentToShow else data.repliesCount

    @allItemsLink = new CustomLinkView
      cssClass    : "all-count"
      pistachio   : "View all {{#(repliesCount)}} comments..."
      click       : @bound "linkClick"
    , data

    @newItemsLink = new CustomLinkView
      cssClass    : "new-items"
      click       : @bound "linkClick"

    {delegate} = options
    delegate.on "AllListed", @bound "reset"

    @liveUpdate = KD.getSingleton('activityController').flags?.liveUpdates or off
    KD.getSingleton('activityController').on "LiveStatusUpdateStateChanged", (@liveUpdate) =>


  linkClick: (event) ->

    KD.utils.stopDOMEvent event
    @emit "ListAll"


  ownCommentArrived: ->

    # Get correct number of items in list from controller
    # I'm not sure maybe its not a good idea
    @onListCount = @parent.commentController?.getItemCount?()

    # If there are same number of comments in list with total
    # comment size means we don't need to show new item count
    @newItemsLink.unsetClass('in')

    # If its our comments so it's not a new comment
    if @newCount > 0 then @newCount--

    @updateNewCount()


  ownCommentDeleted: ->

    @newCount++  if @newCount > 0


  update: ->

    # If there is no comments so we can not have new comments
    if @oldCount is 0 then @newCount = 0

    # If we have comments more than 0 we should show the new item link
    if @newCount > 0
      if @liveUpdate
        @emit "ListAll"
      else
        @setClass 'new'
        @allItemsLink.hide()
        @show()
        @newItemsLink.updatePartial "#{ KD.utils.formatPlural @newCount, 'new comment' }..."
        @newItemsLink.setClass('in')
    else
      @unsetClass 'new'
      @newItemsLink.unsetClass('in')

    if @onListCount > @oldCount
      @onListCount = @oldCount

    if @onListCount is @getData().repliesCount
      @newCount = 0

    if @onListCount is @oldCount and @newCount is 0
      @hide()
    else
      @show()


  reset: ->

    @hide()
    @newCount = 0
    @onListCount = @getData().repliesCount
    @update()


  show: ->

    @setClass "in"

    super


  hide: ->

    @unsetClass "in"

    super


  viewAppended: ->

    super

    {repliesCount} = @getData()

    repliesCount
    unless repliesCount and repliesCount > @maxCommentToShow
      @hide()


  render: ->

    # Get correct number of items in list from controller
    # I'm not sure maybe its not a good idea
    if @parent?.commentController?.getItemCount?()
      @onListCount = @parent.commentController.getItemCount()
    _newCount = @getData().repliesCount

    # Show View all bla bla link if there are more comments
    # than maxCommentToShow
    @show() if _newCount > @maxCommentToShow and @onListCount < _newCount

    # Check the oldCount before update anything
    # if its less means someone deleted a comment
    # otherwise it meanse we have a new comment
    # if nothing changed it means user clicked like button
    # so we don't need to touch anything
    if _newCount > @oldCount
      @newCount++
    else if _newCount < @oldCount
      if @newCount > 0 then @newCount--

    # If the count is changed then we need to update UI
    if _newCount isnt @oldCount
      @oldCount = _newCount
      @utils.defer => @updateNewCount()

    super


  pistachio: ->

    "{{> @allItemsLink}}{{> @newItemsLink}}"
