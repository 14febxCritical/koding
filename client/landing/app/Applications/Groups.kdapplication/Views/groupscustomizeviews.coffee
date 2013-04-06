class StaticPageCustomizeView extends KDView
  constructor:(options,data)->
    super options,data
    @setClass 'group-customize-view'

    @bgSelectView = new StaticGroupBackgroundSelectView
      cssClass  : 'custom-select-background-view'
      delegate  : @

    @bgColorView = new StaticGroupBackgroundColorSelectView
      cssClass  : 'custom-select-background-view'
      delegate  : @

    @settingsLink = new CustomLinkView
      title     : 'Looking for Group Settings?'
      href      : '#'
      cssClass  : 'settings-link'
      click     : =>
        entrypoint = @getDelegate().groupEntryPoint or @getDelegate().profileEntryPoint
        @getSingleton('lazyDomController')?.openPath "/#{entrypoint}/Activity"

    @backButton = new KDButtonView
      title     : 'Back'
      cssClass  : 'back-button modal-cancel'
      callback  : =>
        contentWrapper = @getDelegate().groupContentWrapperView or @getDelegate().profileContentWrapperView
        contentWrapper.unsetClass 'edit'

    @attachListeners()
    @addSettingsButton()

    @fetchStaticPageData =>
      @bgSelectView.decorateList @group
      @bgColorView.decorateList @group

    @staticController = @getSingleton('staticGroupController') ? @getSingleton('staticProfileController')

  addSettingsButton:->
    @settingsLink = new CustomLinkView
      title     : 'Looking for Group Settings?'
      href      : '#'
      cssClass  : 'settings-link'
      click     : =>
        entrypoint = @getDelegate().groupEntryPoint or @getDelegate().profileEntryPoint
        @getSingleton('lazyDomController')?.openPath "/#{entrypoint}/Activity"


  fetchStaticPageData:(callback =->)->
    KD.remote.cacheable @getDelegate().groupEntryPoint, (err,[group],name)=>
      @group = group
      callback group

  attachListeners:->
    @on 'DefaultColorSelected',=>
      @customImageChanged = no
      @defaultColorChanged = yes
      @customColorChanged = no
      @defaultImageChanged = no
      @bgSelectView.thumbsController.deselectAllItems()
      @utils.defer => @emit 'OptionChanged'

    @on 'DefaultImageSelected',=>
      # @emit 'OptionChanged'
      @customImageChanged = no
      @defaultImageChanged = yes
      @customColorChanged = no
      @defaultColorChanged = no
      @bgColorView.thumbsController.deselectAllItems()
      @utils.defer => @emit 'OptionChanged'

    @on 'CustomImageSelected',=>
      @customImageChanged = yes
      @defaultImageChanged = no
      @customColorChanged = no
      @defaultColorChanged = no
      @bgColorView.thumbsController.deselectAllItems()
      @utils.defer => @emit 'OptionChanged'

    @on 'CustomColorSelected',=>
      @customImageChanged = no
      @customColorChanged = yes
      @defaultImageChanged = no
      @defaultColorChanged = no
      @bgSelectView.thumbsController.deselectAllItems()
      @utils.defer => @emit 'OptionChanged'

    @on 'OptionChanged',=>

        if @group

          if @customColorChanged
            defaultIndexItem = @bgColorView.thumbsController.selectedItems.first

            if defaultIndexItem
              pickedColor = defaultIndexItem.color.picker.getValue() or 'fff'
              log pickedColor
              @group.setBackgroundImage 'customColor', pickedColor, (err,res)=>
                unless err
                  new KDNotificationView
                    title : "Background updated with custom color"
                  @customColorChanged = no

          else if @customImageChanged
            url = @bgSelectView.thumbsController.selectedItems.first.customUrl \
            or @bgSelectView.thumbsController.selectedItems.first.getData().url
            if url
              @group.setBackgroundImage 'customImage', url, (err,res)=>
                unless err
                  new KDNotificationView
                    title : "Background updated with custom image"
                  @customImageChanged = no

          else if @defaultImageChanged
              defaultIndexItem = @bgSelectView.thumbsController.selectedItems.first

              if defaultIndexItem
                defaultIndex = defaultIndexItem.getData().dataIndex or 0
                @group.setBackgroundImage 'defaultImage', defaultIndex, (err,res)=>
                  unless err
                    new KDNotificationView
                      title : "Background updated to #{defaultIndexItem.getData().title}"
                    @defaultImageChanged = no

          else if @defaultColorChanged
              defaultIndexItem = @bgColorView.thumbsController.selectedItems.first

              if defaultIndexItem
                defaultHex = defaultIndexItem.getData().colorValue or 0
                @group.setBackgroundImage 'defaultColor', defaultHex, (err,res)=>
                  unless err
                    new KDNotificationView
                      title : "Background updated to color #{defaultIndexItem.getData().title}"
                    @defaultColorChanged = no

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  getBackgroundData:(data={})->
      if data.customize?.background?
        data.customize.background
      else if data.profile.staticPage?.customize?.background?
        data.profile.staticPage.customize.background
      else {}

  pistachio:->
    """
    {{> @backButton}}
    <h1 class="customize-title">Customize this Group page
    <span class="settings-span">({{> @settingsLink}})</span>
    </h1>
    {{> @bgSelectView}}
    {{> @bgColorView}}
    """


class StaticGroupBackgroundUploadView extends KDView

  constructor:(options,data)->
    super options,data

    @uploader = new KDImageUploadView
      cssClass        : 'image-uploader'
      limit           : 1
      preview         : "thumbs"
      extensions      : null
      fileMaxSize     : 2048
      totalMaxSize    : 2048
      fieldName       : "thumbnails"
      convertToBlob   : yes
      title           : ""

    @uploader.on 'FileUploadComplete', (res)=>
      if res.length and res[0].resource
        @getDelegate().getDelegate().getDelegate().staticController.setBackground 'customImage', res[0].resource
        @$().css backgroundImage : "url(#{res[0].resource})"
        @getDelegate().customUrl = res[0].resource

        @getDelegate().emit 'FileUploaded',@

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
    {{> @uploader}}
    """


class StaticGroupBackgroundSelectView extends KDView

  constructor:(options,data)->
    super options,data

    @thumbsController  = new KDListViewController
      itemClass       : StaticGroupBackgroundSelectItemView
      viewOptions     :
        delegate      : @getDelegate()
    @thumbsView = @thumbsController.getView()

    # default items
    items = []
    for i in [1..5]
      items.push
        title     : "Template ##{i}"
        url       : "/images/bg/bg0#{i}.jpg"
        thumbUrl  : "/images/bg/th/bg0#{i}.png"
        dataIndex : i-1
        type      : 'defaultImage'

    items.push
      title       : 'Upload an Image'
      url         : ''
      thumbUrl    : '/images/bg/th/no.png'
      dataIndex   : -1
      type        : 'customImage'

    @thumbsController.instantiateListItems items
    @attachListeners()

  attachListeners:->
    @thumbsController.listView.on 'DefaultImageSelected', (view)=>
      @getDelegate().emit 'DefaultImageSelected', view

    @thumbsController.listView.on 'CustomImageSelected', (view)=>
      @getDelegate().emit 'CustomImageSelected', view

    @thumbsController.listView.on 'FileUploaded', (view)=>
      log 'selecting item',view.getDelegate()
      @thumbsController.selectItem view.getDelegate()
      @getDelegate().emit 'CustomImageSelected', view


  decorateList:(group={})->
    backgroundData = @getDelegate().getBackgroundData group

    if backgroundData.customImages

      for customImage in backgroundData.customImages
        @thumbsController.addItem
          title : 'User Image'
          url : customImage
          thumbUrl : customImage
          dataIndex : -1
          type : 'customImage'
        , 0

    if backgroundData.customType is 'defaultImage'
      for item in @thumbsController.itemsOrdered
        if item.getData().dataIndex is backgroundData.customValue
          @thumbsController.selectItem item

    else @thumbsController.deselectAllItems()

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
    <span class="title">Select a Background</span>
    {{> @thumbsView}}
    """


class StaticGroupBackgroundSelectItemView extends KDListItemView
  constructor:(options,data)->
    super options,data

    @setClass 'custom-image-selectitemview'
    @title = new KDView
      partial : @getData().title

    @type = @getData().type or 'defaultImage'

    if @type is 'defaultImage' or (@type is 'customImage' and @getData().url?.length>0)
      @image = new KDCustomHTMLView
        tagName     : 'img'
        cssClass    : 'custom-image-default'
        attributes  :
          src       : @getData().thumbUrl
          alt       : @getData().title
    else if @type is 'customImage'
      @image = new  StaticGroupBackgroundUploadView
        cssClass : 'custom-image-upload'
        delegate : @
      @image.$().css backgroundImage : "url(#{@getData().thumbUrl})" if @getData().thumbUrl

    @customUrl = null

    @on 'FileUploaded', (view)=>
      @getDelegate().emit 'FileUploaded', view
  click: ->
    # preview live
    if @getData().type is 'defaultImage'
      @getDelegate().emit 'DefaultImageSelected', @
      @getDelegate().getDelegate().staticController.setBackground @type, @getData().url

    else if  @getData().type is 'customImage'
      @getDelegate().emit 'CustomImageSelected', @
      @getDelegate().getDelegate().staticController.setBackground @type, @customUrl or @getData().url

    else log 'Something weird happened'
  viewAppended:->
      super
      @setTemplate @pistachio()
      @template.update()

  pistachio:->
    """
    {{> @image}}
    {{#(title)}}
    """

## *************************
# COLOR SELECT
## *************************

class StaticGroupBackgroundColorSelectView extends KDView

  constructor:(options,data)->
    super options,data

    @thumbsController = new KDListViewController
      itemClass       : StaticGroupBackgroundColorSelectItemView
      viewOptions     :
        delegate      : @getDelegate()

    @thumbsView = @thumbsController.getView()

    # default items
    items = [
      {title:'Pick a color',colorValue:@utils.getRandomHex(), type:'customColor'}
      {title:'Black',colorValue:'#000000', type:'defaultColor'}
      {title:'White',colorValue:'#ffffff', type:'defaultColor'}
      {title:'Transparent',colorValue:'rgba(0,0,0,0.2)', type:'defaultColor'}
      {title:'Koding',colorValue:'#ff9200', type:'defaultColor'}
      {title:'Rhodamine Red C',colorValue:'#E10098', type:'defaultColor'}
      {title:'876 C',colorValue:'#8B634B', type:'defaultColor'}
      {title:'521 C',colorValue:'#A57FB2', type:'defaultColor'}
      {title:'326 C',colorValue:'#00B2A9', type:'defaultColor'}
      {title:'583 C',colorValue:'#B7BF10', type:'defaultColor'}
    ]

    @thumbsController.instantiateListItems items
    @attachListeners()

  attachListeners:->
    @thumbsController.listView.on 'DefaultColorSelected', (view)=>
      @getDelegate().emit 'DefaultColorSelected', view

    @thumbsController.listView.on 'CustomColorSelected', (view)=>
      @getDelegate().emit 'CustomColorSelected', view

  decorateList:(group={})->
    backgroundData = @getDelegate().getBackgroundData group

    if backgroundData.customType is 'defaultColor'
      for item in @thumbsController.itemsOrdered
        if item.getData().colorValue is backgroundData.customValue
          @thumbsController.selectItem item

    if backgroundData.customType is 'customColor'
      for item in @thumbsController.itemsOrdered
        if item.getData().type is 'customColor'
          @thumbsController.selectItem item
          item.decorateCustomColor backgroundData.customValue

    else @thumbsController.deselectAllItems()


  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
    <span class="title">Select a Background</span>
    {{> @thumbsView}}
    """


class StaticGroupBackgroundColorSelectItemView extends KDListItemView
  constructor:(options,data)->
    super options,data

    {@type,colorValue,title} = data = @getData()

    @setClass 'custom-image-selectitemview color'
    @title = new KDView
      partial : title

    @type ?= 'defaultImage'

    if @type is 'defaultColor'
      @color = new KDView
        cssClass : 'custom-color-default'
      @color.$().css backgroundColor : "#{colorValue}"

    else if @type is 'customColor'
      @color = new StaticGroupBackgroundColorPickerView
        cssClass : 'custom-color-picker'
        delegate : @getDelegate()
      ,data

  click: ->
    {type,colorValue} = @getData()

    if type is 'defaultColor'
      @getDelegate().emit 'DefaultColorSelected', @
      @getDelegate().getDelegate().staticController.setBackground type, colorValue

    else if type is 'customColor'
      @getDelegate().emit 'CustomColorSelected', @
      @getDelegate().getDelegate().staticController.setBackground type, @color.picker.getValue()
    else log 'Something weird happened'

  decorateCustomColor:(color)->
    @utils.defer =>
      @getDelegate().getDelegate().staticController.setBackground @type, color
    @color.decorateCustomColor color or '#ff9200'

  viewAppended:->
      super
      @setTemplate @pistachio()
      @template.update()

  pistachio:->
    """
    {{> @color}}
    {{#(title)}}
    """

class StaticGroupBackgroundColorPickerView extends KDView
  constructor:(options,data)->
    super options,data
    {@type, @colorValue} = @getData()
    @picker         = new KDInputView
      cssClass      : 'color-picker'
      bind          : 'keyup'
      defaultValue  : @colorValue
      keyup         : => @updateColor()
      focus         : => @updateColor()
      blur          : => @updateColor()

    @$().css backgroundColor : @picker.getValue()

  updateColor:->
    @$().css backgroundColor : @picker.getValue()
    @getDelegate().getDelegate().staticController.setBackground @type, @picker.getValue()

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  decorateCustomColor:(color)->
    @picker.setValue color
    @$().css backgroundColor : @picker.getValue()

  pistachio:->
    """
    {{> @picker}}
    """