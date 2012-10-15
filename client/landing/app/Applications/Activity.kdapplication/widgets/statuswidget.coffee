class ActivityStatusUpdateWidget extends KDFormView

  constructor:(options,data)->

    super

    {profile} = KD.whoami()

    @smallInput = new KDInputView
      cssClass      : "status-update-input"
      placeholder   : "What's new #{Encoder.htmlDecode profile.firstName}?"
      name          : 'dummy'
      style         : 'input-with-extras'
      focus         : => @switchToLargeView()
      validate      :
        rules       :
          maxLength : 2000

    @previousWhich = 0
    @previousURL = ""

    @largeInput = new KDInputView
      cssClass      : "status-update-input"
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
      blur:=>
        @requestEmbed()
      keydown:=>
        if ($(event.which)[0] is 32) or ($(event.which)[0] is 86 and @previousWhich is 91)
          @requestEmbed()
        @previousWhich = $(event.which)[0]



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

    embedOptions = $.extend {}, options, {
      delegate:@
      hasDropdown : yes
      click:->
        no
    }

    @embedBox = new EmbedBox embedOptions, data

    @heartBox = new HelpBox
      subtitle : "About Status Updates"
      tooltip  :
        title  : "This a public wall, here you can share anything with the Koding community."

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

    @tagAutoComplete = @tagController.getView()

  requestEmbed:=>
    setTimeout =>
      firstUrl = @largeInput.getValue().match(/([a-zA-Z]+\:\/\/)?(\w+:\w+@)?([a-zA-Z\d.-]+\.[A-Za-z]{2,4})(:\d+)?(\/.*\S)?/g)
      unless @previousURL is firstUrl?[0] then unless firstUrl is null then @embedBox.embedUrl firstUrl?[0], {
        maxWidth: 525
      }
      @previousURL = firstUrl?[0]
    ,500

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

  switchToEditView:(activity)->
    {tags, body} = activity
    @tagController.reset()
    @tagController.setDefaultValue tags
    @submitBtn.setTitle "Edit status update"
    @addCustomData "activity", activity
    @largeInput.setValue Encoder.htmlDecode body
    @switchToLargeView()
    @utils.selectText @largeInput.$()[0]

  submit:->
    @once 'FormValidationPassed', => @reset()
    super

  reset:->
    @tagController.reset()
    @submitBtn.setTitle "Submit"
    @removeCustomData "activity"
    @embedBox.clearEmbedAndHide()
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
    <div class="large-input">{{> @largeInput}}</div>
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
