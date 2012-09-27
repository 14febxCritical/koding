class OpinionViewHeader extends JView

  constructor:(options = {}, data)->

    options.cssClass       = "show-more-opinions in"
    options.itemTypeString = options.itemTypeString or "answers"

    super options, data

    data = @getData()

    @maxCommentToShow = 5
    @oldCount         = data.repliesCount
    @newCount         = 0
    @onListCount      = if data.repliesCount > @maxCommentToShow then @maxCommentToShow else data.repliesCount

    # The snapshot view should always have a visible Header

    if @parent?.constructor is not DiscussionActivityOpinionView
      unless data.repliesCount? and data.repliesCount > @maxCommentToShow
        @onListCount = data.repliesCount
        @hide()
      @hide() if data.repliesCount < @maxCommentToShow

    list = @getDelegate()

    list.on "AllOpinionsWereAdded", =>
      @show()
      @newCount = 0
      @onListCount = @getData().repliesCount
      @updateNewCount()
      @allItemsLink.unsetClass "in"
      @newItemsLink.unsetClass "in"
      @loader.hide()
      @newAnswers = 0

    @allItemsLink = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "all-count"
      partial   : "View #{@maxCommentToShow} more #{@getOptions().itemTypeString}"
      click     : =>
        @loader.show()
        @newItemsLink.unsetClass "in"
        list.emit "AllOpinionsLinkWasClicked", @
    , data

    list.on "RelativeOpinionsWereAdded",  =>
      @updateRemainingText()

      if @getDelegate().items.length<@getData().repliesCount
        @loader.hide()
      else
        @loader.hide()
        @allItemsLink.unsetClass "in"

      @newItemsLink.unsetClass "in"
      @newAnswers = 0
      @show()

    @loader = new KDLoaderView
      cssClass      : "opinion-loader hidden"
      size          :
        width       : 20
      loaderOptions :
        color       : "#FD7E09"
        shape       : "spiral"
        diameter    : 12
        density     : 30
        range       : 0.4
        speed       : 2
        FPS         : 24

    @newItemsLink = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "new-items"
      click     : =>
        list.emit "AllOpinionsLinkWasClicked", @

    @newAnswers = 0

    list.on "NewOpinionHasArrived",=>
      @newAnswers++
      @updateRemainingText()
      @newItemsLink.updatePartial "#{if @newAnswers is 0 then "No" else @newAnswers} new Answer#{if @newAnswers is 1 then "" else "s"}"

      @setClass "has-new-items"
      @show()
      @allItemsLink.show()
      @allItemsLink.setClass "in"
      @newItemsLink.show()
      @newItemsLink.setClass "in"

  hide:->
    @unsetClass "in"
    super

  show:->
    @setClass "in"
    super

  viewAppended:=>
    @setTemplate @pistachio()
    @template.update()

    @updateRemainingText()

    # This will hide the bar in the CD when there is nothing there yet. Once
    # content pops up, the event handling it will show the bar again

    if @parent?.constructor is OpinionView
      @hide() if @getData().repliesCount is 0

  updateRemainingText:=>
    if not @parent? or  @parent.constructor is DiscussionActivityOpinionView
      @allItemsLink.updatePartial "View entire Discussion"
    else
      remainingOpinions = @getData().repliesCount-@getDelegate().items.length
      if (remainingOpinions)<@maxCommentToShow
          if remainingOpinions is 1
            @allItemsLink.updatePartial "View remaining answer"
          else if remainingOpinions > 1
            @allItemsLink.updatePartial "View remaining #{remainingOpinions} #{@getOptions().itemTypeString}"
          else
            if @newAnswers is 0
              @allItemsLink.updatePartial ""
            else
              @allItemsLink.updatePartial "View new answers"

  pistachio:->
    """
      {{> @allItemsLink}}{{> @newItemsLink}}
      {{> @loader}}
    """