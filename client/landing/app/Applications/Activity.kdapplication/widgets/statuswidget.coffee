class ActivityStatusUpdateWidget extends KDFormView

  constructor:(options,data)->

    super

    {profile} = KD.whoami()

    @smallInput = new KDInputView
      cssClass      : "status-update-input warn-on-unsaved-data"
      placeholder   : "What's new #{Encoder.htmlDecode profile.firstName}?"
      name          : 'dummy'
      style         : 'input-with-extras'
      focus         : @bound 'switchToLargeView'
      validate      :
        rules       :
          maxLength : 2000

    # saves the URL of the previous request to avoid
    # multiple embed calls for one URL
    @previousURL = ""

    # prevents multiple calls to embed.ly functionality
    # at the same time
    @requestEmbedLock = off

    # will show the loader/embed box instantly when embed
    # requests gets parsed/sent. this is only needed if the
    # box is hidden (as it is when the widget is empty or reset)
    @initialRequest = yes

    @largeInput = new KDInputView
      cssClass      : "status-update-input warn-on-unsaved-data"
      type          : "textarea"
      placeholder   : "What's new #{Encoder.htmlDecode profile.firstName}?"
      name          : 'body'
      style         : 'input-with-extras'
      autogrow      : yes
      validate      :
        rules       :
          required  : yes
          maxLength : 3000
        messages    :
          required  : "Please type a message..."

      paste:=>
        @requestEmbed()

      # # this will cause problems when clicking on a embedLinks url
      # # right after entering the url -> double request
      # the request lock should circumvent this problem.

      blur:=>
        @utils.wait 1000, =>
          @requestEmbed()

      keyup:=>
        # this needs to be refactored, this will only capture URLS when the user
        # adds a space after them or tabs out
        if ($(event.which)[0] is 32) or ($(event.which)[0] is 9) # when space key is hit, URL is usually complete
          @requestEmbed()

    @cancelBtn = new KDButtonView
      title       : "Cancel"
      style       : "modal-cancel"
      callback    : =>
        @reset()
        @parent.getDelegate().emit "ResetWidgets"

    @submitBtn = new KDButtonView
      style       : "clean-gray"
      title       : "Submit"
      type        : "submit"

    embedOptions = $.extend {}, options,
      delegate  : @
      hasConfig : yes
      click:->
        no

    @embedBox = new EmbedBox embedOptions, data

    @embedUnhideLink = new KDCustomHTMLView
      cssClass : 'unhide-embed-link'
      tagName : "a"
      partial : "Re-enable embedding URLs"
      attributes :
        href : ""
      click :(event)=>
        event.preventDefault()
        event.stopPropagation()
        @embedBox.show()
        @embedBox.removeEmbedHiddenItem "embed"
        @embedUnhideLink.hide()

    @embedUnhideLink.hide()
    @embedBox.on "EmbedIsHidden", =>
      @embedUnhideLink.show()

    @heartBox = new HelpBox
      subtitle : "About Status Updates"
      tooltip  :
        title  : "This is a public wall, here you can share anything with the Koding community."

    @labelAddTags = new KDLabelView
      title : "Add Tags:"

    @selectedItemWrapper = new KDCustomHTMLView
      tagName  : "div"
      cssClass : "tags-selected-item-wrapper clearfix"

    @tagController = new TagAutoCompleteController
      name                : "meta.tags"
      type                : "tags"
      itemClass           : TagAutoCompleteItemView
      selectedItemClass   : TagAutoCompletedItemView
      outputWrapper       : @selectedItemWrapper
      selectedItemsLimit  : 5
      listWrapperCssClass : "tags"
      itemDataPath        : 'title'
      form                : @
      dataSource          : (args, callback)=>
        {inputValue} = args
        updateWidget = @getDelegate()
        blacklist = (data.getId() for data in @tagController.getSelectedItemData() when 'function' is typeof data.getId)
        appManager.tell "Topics", "fetchTopics", {inputValue, blacklist}, callback


    @inputLinkInfoBox = new InfoBox
      cssClass : "protocol-info-box"
      delegate : @

    @inputLinkInfoBox.hide()

    @tagAutoComplete = @tagController.getView()

    # checkbox autocheck
    @appStorage = new AppStorage 'Activity', '1.0'
    @updateCheckboxFromStorage()

  updateCheckboxFromStorage:->
    @appStorage.fetchValue 'UrlSanitizerCheckboxIsChecked',(checked)=>
      @inputLinkInfoBox.setSwitchValue checked

  # will automatically add // to any non-protocol urls
  sanitizeUrls:(text)->
    text.replace /([a-zA-Z]+\:\/\/)?(\w+:\w+@)?[a-zA-Z\d\.-]+\.([a-zA-Z]{2,4}(:\d+)?)([\/\?]\S*)?\b/g, (url)=>
      test = /^([a-zA-Z]+\:\/\/)/.test url
      if test is no

        # here is a warning/popup that explains how and why
        # we change the links in the edit

        unless @inputLinkInfoBox.inputLinkInfoBoxPermaHide is on then @inputLinkInfoBox.show()

        if @inputLinkInfoBox.getSwitchValue() is yes
          "http://"+url
        else
          url

      else

        # if a protocol of any sort is found, no change
        url

  requestEmbed:->

    @largeInput.setValue @sanitizeUrls @largeInput.getValue()

    unless "embed" in @embedBox.getEmbedHiddenItems() or @requestEmbedLock is on

      @requestEmbedLock = on

      setTimeout =>
        firstUrl = @largeInput.getValue().match(/([a-zA-Z]+\:\/\/)?(\w+:\w+@)?[a-zA-Z\d\.-]+\.([a-zA-Z]{2,4}(:\d+)?)([\/\?]\S*)?\b/g)
        if firstUrl?

          if @initialRequest
            @initialRequest = no

          @embedBox.embedLinks.setLinks firstUrl
          @embedBox.show()

          unless (@previousURL in firstUrl)
            @embedBox.embedUrl firstUrl?[0], {
              maxWidth: 525
            }, (embedData)=>

              # add favicon to link list if possible
              # @embedLinks?.linkList?.items?[0]?.setFavicon embedData.favicon_url

              @requestEmbedLock = off
              @previousURL = firstUrl?[0]

          else
            @requestEmbedLock = off
        else
          @requestEmbedLock = off
      ,50

  switchToSmallView:->

    @parent.setClass "no-shadow" if @parent # monkeypatch when loggedout this was giving an error
    @largeInput.setHeight 33
    @$('>div.large-input, >div.formline').hide()
    @smallInput.show()

  switchToLargeView:->

    @parent.unsetClass "no-shadow" if @parent # monkeypatch when loggedout this was giving an error
    @smallInput.hide()
    @$('>div.large-input, >div.formline').show()

    @utils.wait =>
      @largeInput.$().trigger "focus"
      @largeInput.setHeight 72

    # Do we really need this? Without that it works great.
    # yes we need this but with an improved implementation
    # it shouldn't reset non-submitted inputs
    # check widgetview.coffee:23-27-33
    tabView = @parent.getDelegate()
    @getSingleton("windowController").addLayer tabView

  switchToEditView:(activity,fake=no)->
    {tags, body, link} = activity
    @tagController.reset()
    @tagController.setDefaultValue tags

    unless fake
      @submitBtn.setTitle "Edit status update"
      @addCustomData "activity", activity
    else
      @submitBtn.setTitle "Submit again"

    @largeInput.setValue Encoder.htmlDecode body
    @utils.selectText @largeInput.$()[0]

    if link? and link.link_url isnt ''

      bodyUrls = @largeInput.getValue().match(/([a-zA-Z]+\:\/\/)?(\w+:\w+@)?([a-zA-Z\d.-]+\.[A-Za-z]{2,4})(:\d+)?(\/\S*)?/g)
      if bodyUrls?

        # put the item with link_url as its url to array[0] for auto-active
        selected = bodyUrls.splice(bodyUrls.indexOf(link.link_url),1)
        bodyUrls.unshift selected[0]
        @embedBox.embedLinks.setLinks bodyUrls

      @previousURL = link.link_url

      @embedBox.setEmbedData link.link_embed
      @embedBox.setEmbedURL link.link_url
      @embedBox.setEmbedImageIndex link.link_embed_image_index
      @embedBox.setEmbedHiddenItems link.link_embed_hidden_items
      @embedBox.setEmbedCache link.link_cache

      # when in edit mode, show the embed and remove any "embed" from hidden
      @embedBox.embedExistingData link.link_embed, {forceShow:yes}, =>
        @embedBox.show()
        @embedUnhideLink.hide()
      , link.link_cache
    else
      @embedBox.hide()

    @switchToLargeView()

  submit:->


    @addCustomData "link_cache", @embedBox.getEmbedCache() or []
    @addCustomData "link_url", @embedBox.getEmbedURL() or ""
    @addCustomData "link_embed", @embedBox.getEmbedDataForSubmit() or {}
    @addCustomData "link_embed_hidden_items", @embedBox.getEmbedHiddenItems() or []
    @addCustomData "link_embed_image_index", @embedBox.getEmbedImageIndex() or 0

    @once 'FormValidationPassed', => @reset()

    super

    @submitBtn.disable()
    @utils.wait 8000, => @submitBtn.enable()

  reset:->
    @tagController.reset()
    @submitBtn.setTitle "Submit"
    @removeCustomData "activity"
    @removeCustomData "link_url"
    @removeCustomData "link_cache"
    @removeCustomData "link_embed"
    @removeCustomData "link_embed_hidden_items"
    @removeCustomData "link_embed_image_index"
    @embedBox.resetEmbedAndHide()
    @previousURL = ""
    @initialRequest = yes
    @inputLinkInfoBoxPermaHide = off
    @inputLinkInfoBox.hide()
    @updateCheckboxFromStorage()

    super

  viewAppended:->
    @setTemplate @pistachio()
    @template.update()
    @switchToSmallView()
    tabView = @parent.getDelegate()
    tabView.on "MainInputTabsReset", =>
      @reset()
      @switchToSmallView()



  pistachio:->
    """
    <div class="small-input">{{> @smallInput}}</div>
    <div class="large-input">
      {{> @largeInput}}
      {{> @inputLinkInfoBox}}
      <div class="unhide-embed">
      {{> @embedUnhideLink}}
      </div>
    </div>
    <div class="formline">
    {{> @embedBox}}
    </div>
    <div class="formline">
      {{> @labelAddTags}}
      <div>
        {{> @selectedItemWrapper}}
        {{> @tagAutoComplete}}
      </div>
    </div>
    <div class="formline submit">
      <div class='formline-wrapper'>
        <div class="submit-box fr">
          {{> @submitBtn}}
          {{> @cancelBtn}}
        </div>
        {{> @heartBox}}
      </div>
    </div>
    """

class InfoBox extends KDView
  constructor:->
    super
    # will hide the link helper box once it's been closed once
    @inputLinkInfoBoxPermaHide = off

    stopSanitizingToolTip = {
      title:"This feature automatically adds protocols to URLs detected in your message."
      position: "below"
      gravity : "s"
    }

    @stopSanitizingLabel = new KDLabelView
      title : "URL auto-completion"
      tooltip : stopSanitizingToolTip


    @stopSanitizingOnOffSwitch = new KDOnOffSwitch
      label : @stopSanitizingLabel
      name :"stop-sanitizing"
      cssClass : "stop-sanitizing"
      tooltip : stopSanitizingToolTip

      callback:(state)=>
        @getDelegate().appStorage.setValue 'UrlSanitizerCheckboxIsChecked', state, =>
          if state
            @getDelegate().largeInput.setValue @getDelegate().sanitizeUrls @getDelegate().largeInput.getValue()


    @inputLinkInfoBoxCloseButton = new KDButtonView
      name: "hide-info-box"
      cssClass      : "hide-info-box"
      icon      : yes
      iconOnly  : yes
      iconClass : "hide"
      title     : "Close"
      callback  : =>
        @hide()
        @inputLinkInfoBoxPermaHide = on

  getSwitchValue:->
    @stopSanitizingOnOffSwitch.getValue()

  setSwitchValue:(value)->
    @stopSanitizingOnOffSwitch.setValue value

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()
  pistachio:->"""
      <p>For links, please provide a protocol such as
        <abbr title="Hypertext Transfer Protocol">http://</abbr>
      </p>
      <div class="sanitizer-control">
        {{> @stopSanitizingLabel}}
        {{> @stopSanitizingOnOffSwitch}}
      </div>
      {{> @inputLinkInfoBoxCloseButton}}
  """
