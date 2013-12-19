class ActivityTutorialWidget extends ActivityWidgetFormView

  constructor :(options,data)->

    super options,data

    @preview = options.preview or {}

    @labelTitle = new KDLabelView
      title     : "New Tutorial"
      cssClass  : "first-label"

    @labelEmbedLink = new KDLabelView
      title : "Video URL:"

    @labelContent = new KDLabelView
      title : "Content:"

    @inputDiscussionTitle = new KDInputView
      name          : "title"
      label         : @labelTitle
      cssClass      : "warn-on-unsaved-data"
      placeholder   : "Give a title to your Tutorial..."
      validate      :
        rules       :
          required  : yes
        messages    :
          required  : "Tutorial title is required!"

    @inputTutorialEmbedShowLink = new KDOnOffSwitch
      cssClass      : "show-tutorial-embed"
      defaultState  : off
      callback      : (state)=>
        if state
          if @embedBox.hasValidContent
            @embedBox.show()
            @embedBox.$().animate {top: "0px"}, 300
        else
          @embedBox.$().animate {top : "-400px"}, 300, => @embedBox.hide()

    @inputTutorialEmbedLink = new KDInputView
      name          : "embed"
      label         : @labelEmbedLink
      cssClass      : "warn-on-unsaved-data tutorial-embed-link"
      placeholder   : "Please enter a URL to a video..."
      keyup         : =>
        @embedBox.resetEmbedAndHide()  if @inputTutorialEmbedLink.getValue() is ''
      paste         : =>
          @utils.defer =>
            @inputTutorialEmbedLink.setValue @sanitizeUrls @inputTutorialEmbedLink.getValue()

            url = @inputTutorialEmbedLink.getValue().trim()

            if /^((http(s)?\:)?\/\/)/.test url
              # parse this for URL
              embedOptions = maxWidth: 540, maxHeight: 200
              @embedBox.embedUrl url, embedOptions, =>
                @embedBox.hide()  if @inputTutorialEmbedShowLink.getValue() is off

    embedOptions = $.extend {}, options,
      delegate  : this
      hasConfig : yes
      forceType : "object"

    @embedBox = new EmbedBox embedOptions, data

    @inputContent = new KDInputViewWithPreview
      label       : @labelContent
      preview     : @preview
      name        : "body"
      cssClass    : "discussion-body warn-on-unsaved-data"
      type        : "textarea"
      autogrow    : yes
      placeholder : "Please enter your Tutorial content. (You can use markdown here)"
      validate    :
        rules     :
          required: yes
        messages  :
          required: "Tutorial content is required!"

    @cancelBtn = new KDButtonView
      title    : "Cancel"
      style    : "modal-cancel"
      callback : =>
        @reset()
        @parent.getDelegate().emit "ResetWidgets"

    @submitBtn = new KDButtonView
      style : "clean-gray"
      title : "Post your Tutorial"
      type  : 'submit'

    @heartBox = new HelpBox
      subtitle : "About Tutorials"
      tooltip  :
        title  : "This is a public wall, here you can share your tutorials with the Koding community."

  sanitizeUrls:(text)->
    text.replace /(([a-zA-Z]+\:)\/\/)?(\w+:\w+@)?([a-zA-Z\d.-]+\.[A-Za-z]{2,4})(:\d+)?(\/\S*)?/g, (url)=>
      test = /^([a-zA-Z]+\:\/\/)/.test url
      if test then url else "http://"+url

  submit:->
    @once "FormValidationPassed", =>
      KD.track "Activity", "TutorialSubmitted"
      @reset()

    if @embedBox.hasValidContent
      @addCustomData "link",
        link_url   : @embedBox.url
        link_embed : @embedBox.getDataForSubmit()

    super
    @submitBtn.disable()
    @utils.wait 8000, => @submitBtn.enable()

  reset:->
    @submitBtn.setTitle "Post your Tutorial"
    @removeCustomData "activity"
    @inputDiscussionTitle.setValue ''
    @inputContent.setValue ''
    @inputContent.resize()
    @inputTutorialEmbedShowLink.setValue off
    @embedBox.resetEmbedAndHide()

    # deferred resets
    @utils.wait 2000, => @tagController.reset()

    super

  viewAppended:->
    @setClass "update-options discussion"
    @setTemplate @pistachio()
    @template.update()

  switchToEditView:(activity,fake=no)->

    unless fake
      @submitBtn.setTitle "Edit Tutorial"
      @addCustomData "activity", activity
    else
      @submitBtn.setTitle 'Submit again'

    {title, body, tags, link} = activity

    @tagController.reset()
    @tagController.setDefaultValue tags or []

    fillForm = =>
      @inputDiscussionTitle.setValue KD.utils.htmlDecode title
      @inputContent.setValue KD.utils.htmlDecode body
      @inputTutorialEmbedLink.setValue KD.utils.htmlDecode link?.link_url
      @inputContent.generatePreview()

    fillForm()

            # {{> @followupLink}}
  pistachio:->
    """
    <div class="form-actions-mask">
      <div class="form-actions-holder">
        <div class="formline">
          {{> @labelTitle}}
          <div>
            {{> @inputDiscussionTitle}}
          </div>
        </div>
        <div class="formline">
          {{> @labelEmbedLink}}
          <div>
            {{> @inputTutorialEmbedLink}}
            {{> @inputTutorialEmbedShowLink}}
            {{> @embedBox}}
          </div>
        </div>
        <div class="formline">
          {{> @labelContent}}
          <div>
            {{> @inputContent}}
          </div>
        </div>
        <div class="formline">
          {{> @labelAddTags}}
          <div>
            {{> @tagAutoComplete}}
            {{> @selectedItemWrapper}}
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
      </div>
    </div>
    """