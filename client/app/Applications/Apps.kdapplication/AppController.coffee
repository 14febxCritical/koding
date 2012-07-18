class Apps12345 extends AppController
  constructor:(options, data)->
    options = $.extend
      view : new AppsMainView 
        cssClass : "content-page appstore"
    ,options
    super options,data
  
  bringToFront:()->
    @propagateEvent (KDEventType : 'ApplicationWantsToBeShown', globalEvent : yes),
      options :
        name : 'Apps'
      data : @getView()
    
  initAndBringToFront:(options,callback)->
    @bringToFront()
    callback()
    
  loadView:(mainView)->
    mainView.createCommons()
    # @createFeed()

  createFeed:(view)->
    appManager.tell 'Feeder', 'createContentFeedController', {
      subItemClass          : AppsListItemView
      limitPerPage          : 20
      filter                :
        webApps             :
          title             : "Web Apps"
          dataSource        : (selector, options, callback)=>
            bongo.api.JApp.someWithRelationship selector, options, callback
        kodingAddOns        :
          title             : "Koding Add-ons"
          dataSource        : (selector, options, callback)=>
            setTimeout =>
              callback null,@dummy
            ,200
        serverStacks        :
          title             : "Server Stacks"
          dataSource        : (selector, options, callback)=>
            setTimeout =>
              callback null,@dummy
            ,200
        frameworks          :
          title             : "Frameworks"
          dataSource        : (selector, options, callback)=>
            setTimeout =>
              callback null,@dummy
            ,200
      sort                  :
        'counts.followers'  :
          title             : "Most popular"
          direction         : -1
        'meta.modifiedAt'   :
          title             : "Latest activity"
          direction         : -1
        'counts.tagged'     :
          title             : "Most activity"
          direction         : -1
      help                  :
        subtitle            : "Learn About Apps"
        tooltip :
          title     : "<p class=\"bigtwipsy\">The App Catalog contains apps and Koding enhancements contributed to the community by users.</p>"
          placement : "above"
          offset    : 0
          delayIn   : 300
          html      : yes
          animate   : yes
          
          
    }, (controller)=>
      for own name,listController of controller.resultsController.listControllers
        listController.getListView().registerListener
          KDEventTypes  : 'AppWantsToExpand'
          listener      : @
          callback      : (pubInst, app)=>
            @createContentDisplay app

      @getView().addSubView controller.getView()
      @feedController = controller
      @putAddAnAppButton()

  fetchAutoCompleteDataForTags:(inputValue,blacklist,callback)->
    bongo.api.JTag.byRelevance inputValue, {blacklist}, (err,tags)->
      unless err
        callback? tags
      else
        log "there was an error fetching topics"
  
  createContentDisplay:(app, doShow = yes)->
    @showContentDisplay app

  showContentDisplay:(content)->
    contentDisplayController = @getSingleton "contentDisplayController"
    controller = new ContentDisplayControllerApps null, content
    contentDisplay = controller.getView()
    contentDisplayController.propagateEvent KDEventType : "ContentDisplayWantsToBeShown",contentDisplay

  putAddAnAppButton:->
    {facetsController} = @feedController
    innerNav = facetsController.getView()
    innerNav.addSubView addButton = new KDButtonView
      title     : "Add an App"
      style     : "small-gray"
      callback  : => @showAppSubmissionView()

  createApp:(formData,callback)->
    log formData,"in createApp"
    # log JSON.stringify formData
    bongo.api.JApp.create formData, (err, app)->
      callback? err,app

  showAppSubmissionView:->
    modal       = new AppSubmissionModal
    modal.$().css top : 75
    {modalTabs} = modal
    {forms}     = modalTabs
    modal.registerListener
      KDEventTypes  : "AppSubmissionFormSubmitted"
      listener      : @
      callback      : (pubInst,formData)=>
        @createApp formData, (err,res)=>
          unless err
            new KDNotificationView
              title : "App created successfully!"
            modal.destroy()
          else
            warn "there was an error creating the app",err
            new KDNotificationView
              title : "there was an error creating the app"
        
    modalTabs.registerListener
      KDEventTypes  : "PaneDidShow"
      listener      : @
      callback      : (pubInst,event)=>
        # scriptForm = forms['Technical Stuff']
        # scriptForm.addCustomData "scriptCode", scriptForm.ace.getValue()
        # scriptForm.addCustomData "scriptSyntax", scriptForm.ace.getActiveSyntaxName()
        # scriptForm.addCustomData "requirementsCode", scriptForm.reqs.getValue()
        # scriptForm.addCustomData "requirementsSyntax", scriptForm.reqs.getActiveSyntaxName()
        if event.pane.name is "Review & Submission"
          @createAppSummary modal, event.pane
    
    # TAGS AUTOCOMPLETE
    selectedItemWrapper = new KDCustomHTMLView
      tagName  : "div"
      cssClass : "tags-selected-item-wrapper clearfix"

    tagController = new TagAutoCompleteController
      name                : "meta.tag"
      type                : "tags"
      itemClass           : TagAutoCompleteItemView
      selectedItemClass   : TagAutoCompletedItemView
      outputWrapper       : selectedItemWrapper
      listWrapperCssClass : "tags"
      form                : forms['Technical Stuff']
      itemDataPath        : 'title'
      dataSource          : (args, callback)=>
        {inputValue} = args
        blacklist = (data.getId() for data in tagController.getSelectedItemData() when 'function' is typeof data.getId)
        @fetchAutoCompleteDataForTags inputValue,blacklist,callback
    
    tagAutoComplete = tagController.getView()
    tagsField       = forms['Technical Stuff'].fields.Tags
    tagsField.addSubView tagAutoComplete
    tagsField.addSubView selectedItemWrapper

    modal.registerListener
      KDEventTypes  : "KDModalViewDestroyed"
      listener      : @
      callback      : ->
        tagController.destroy()
    
    # # INSTALL SCRIPT ACE
    # scriptForm      = forms['Technical Stuff']
    # scriptField     = scriptForm.fields.Script
    # 
    # scriptField.addSubView aceWrapper = new KDCustomHTMLView
    #   cssClass : "code-snip-holder dark-select"
    # 
    # aceWrapper.addSubView scriptForm.ace = new MiniAceEditor
    #   defaultValue  : "# Type your install script here..."
    #   autoGrow      : yes
    #   path          : "~~~/dummy-path/dummy.coffee"
    #   name          : "dummy.coffee"
    # 
    # scriptForm.ace.on 'sizes.height.change', (options) =>
    #   {height} = options
    #   scriptForm.ace.$().parent().height height + 25
    # 
    # scriptForm.ace.refreshEditorView()
    # scriptForm.ace.saveSyntaxForExtension "coffee"

    # # REQUIREMENTS SCRIPT ACE
    # reqsField        = scriptForm.fields.Reqs
    # 
    # reqsField.addSubView reqsWrapper = new KDCustomHTMLView
    #   cssClass : "code-snip-holder dark-select"
    # 
    # reqsWrapper.addSubView scriptForm.reqs = new MiniAceEditor
    #   defaultValue  : "# Type your requirement options here..."
    #   autoGrow      : yes
    #   path          : "~~~/dummy-path/dummy.coffee"
    #   name          : "dummy.coffee"
    # 
    # scriptForm.reqs.on 'sizes.height.change', (options) =>
    #   {height} = options
    #   scriptForm.ace.$().parent().height height + 55
    # 
    # scriptForm.reqs.refreshEditorView()
    # scriptForm.reqs.saveSyntaxForExtension "coffee"
    
    # IMAGE UPLOADERS
    thumbField = forms.Visuals.fields.thumbnail
    thumbField.addSubView thumbUploader = new KDImageUploadView
      limit           : 1
      preview         : "thumbs"
      extensions      : null
      fileMaxSize     : 512
      totalMaxSize    : 512
      fieldName       : "thumbnails"
      convertToBlob   : yes
      actions         : {
        listThumb     :
          [
            'scale', {
              shortest: 160
            }
            'crop', {
              width   : 160
              height  : 80
            }
          ]
        appThumb      :
          [
            'scale', {
              shortest: 90
            }
            'crop', {
              width   : 90
              height  : 90
            }
          ]
      }
      title           : "Drop a logo of the app here..."
    
    screenshotsField = forms.Visuals.fields.screenshots
    screenshotsField.addSubView thumbUploader = new KDImageUploadView
      limit           : 10
      preview         : "thumbs"
      extensions      : null
      fileMaxSize     : 512
      totalMaxSize    : 4096
      fieldName       : "screenshots"
      convertToBlob   : yes
      actions         : {
        screenshot    :
          [
            'scale', {
              shortest: 768
            }
            'crop', {
              width   : 1024
              height  : 768
            }
          ]
        thumb         :
          [
            'scale', {
              shortest: 96
            }
            'crop', {
              width   : 96
              height  : 96
            }
          ]
      }
      title           : "Drop some screenshots here..."
      
  createAppSummary:(modal, pane)->
    modal.preview.destroy() if modal.preview
    formData = modal.modalTabs.getFinalData()
    log formData
    pane.form.addSubView (modal.preview = new AppPreSubmitPreview {},formData),null,yes
    
    
    








