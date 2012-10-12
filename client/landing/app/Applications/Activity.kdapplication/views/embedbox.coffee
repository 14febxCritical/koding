class EmbedBox extends KDView
  constructor:(options={}, data={})->

    account = KD.whoami()

    @embedData = {}
    @embedURL = ''

    @embedHiddenItems = data.link_embed_hidden_items or []

    super options,data

    if (@getDelegate() instanceof ActivityLinkWidget) or data.originId? and (data.originId is KD.whoami().getId()) or KD.checkFlag 'super-admin'
      @settingsButton = new KDButtonViewWithMenu
        cssClass    : 'transparent activity-settings-context activity-settings-menu embed-box-settings'
        title       : ''
        icon        : yes
        delegate    : @
        iconClass   : "arrow"
        menu        : @settingsMenu data
        callback    : (event)=>
          event.preventDefault()
          @settingsButton.contextMenu event
    else
      @settingsButton = new KDCustomHTMLView tagName : 'span', cssClass : 'hidden'


    @setClass "link-embed-box"

    @embedLoader = new KDLoaderView
      cssClass      : "hidden"
      size          :
        width       : 30
      loaderOptions :
        color       : "#444"
        shape       : "spiral"
        diameter    : 30
        density     : 30
        range       : 0.4
        speed       : 1
        FPS         : 24

    unless data is {} then @hide()

  settingsMenu:(data)->

    account        = KD.whoami()
    mainController = @getSingleton('mainController')


    # only during creation of when the user is the link owner should
    # this menu exist

    if data.originId is KD.whoami().getId() or (@getDelegate() instanceof ActivityLinkWidget)
      menu =
        'Remove Image from Preview' :
          callback : =>
            @addEmbedHiddenItem "image"
            @refreshEmbed()
            @getDelegate()?.emit "embedHideItem", @embedHiddenItems
            no
        'Remove Preview'   :
          callback : =>
            @embedHiddenItems.push "embed"
            @refreshEmbed()
            @getDelegate()?.emit "embedHideItem", @embedHiddenItems
            no

      return menu

  viewAppended:->
    super()
    @setTemplate @pistachio()
    @template.update()

  refreshEmbed:=>
    @populateEmbed @getEmbedData(), @embedURL

  resetEmbedAndHide:=>
    @resetEmbed()
    @hide()

  resetEmbed:=>
    @clearEmbed()
    @setEmbedData {}
    @setEmbedURL ''
    @setEmbedHiddenItems []

  clearEmbed:=>
    @$("div.embed").html ""

  clearEmbedAndHide:=>
    @clearEmbed()
    @hide()

  getEmbedData:=>
    @embedData

  getEmbedURL:=>
    @embedURL

  getEmbedHiddenItems:=>
    @embedHiddenItems

  setEmbedData:(data)=>
    @embedData = data

  setEmbedURL:(url)=>
    @embedURL = url

  setEmbedHiddenItems:(ehi)=>
    @embedHiddenItems = ehi

  addEmbedHiddenItem:(item)=>
    if not (item in @embedHiddenItems) then @embedHiddenItems.push item

  fetchEmbed:(url="#",options={},callback=noop)=>

    requirejs ["http://scripts.embed.ly/jquery.embedly.min.js"], (embedly)=>
      embedlyOptions = $.extend {}, {
        key      : "e8d8b766e2864a129f9e53460d520115"
        endpoint : "preview"
        maxWidth : 560
        maxHeight: 300
        wmode    : "transparent"
        error    : (node, dict)=>
          callback? dict
      }, options

      # if there is no protocol, supply one! embedly doesn't support //
      unless /^(ht|f)tp(s?)\:\/\//.test url then url = "http://"+url

      $.embedly url, embedlyOptions, (oembed, dict)=>
        @setEmbedData oembed
        @setEmbedURL url
        callback oembed,embedlyOptions

  populateEmbed:(data={},url="#",options={})=>

    if "embed" in @getEmbedHiddenItems()
      @hide()
      return no

    if data?.safe? and data?.safe is yes

      # replace this when using preview instead of oembed
      prettyLink = (link)->
        link.replace("http://","").replace("https://","").replace("www.","")

      type = data?.object?.type or "link"

      switch type
        when "html" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "audio" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "video" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "text" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "xml" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "json" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "ppt" then html = data?.object?.html or "This link has no Preview available. Oops."
        when "rss","atom" then html = data?.object?.html or "This link has no Preview available. Oops."

        # this is usually just a single image
        when "photo","image"
          html = """<img src="#{data?.images?[0]?.url}" style="max-width:#{options.maxWidth+"px" or "560px"};max-height:#{options.maxHeight+"px" or "300px"}" title="#{data?.title or ""}" /> """
          if ("image" in @getEmbedHiddenItems())
            @hide()

        # rich is a html object for things like twitter posts
        when "rich"
          html = data?.object?.html
          html = $(html).addClass "custom-twitter"

        # fallback for things that may or may not have any kind of preview
        when "link"
          html = """
              <div class="preview_image #{if ("image" in @getEmbedHiddenItems()) or not data?.images?[0]? then "hidden" else ""}">
                <a class="preview_link" target="_blank" href="#{data.url or url}"><img class="thumb" src="#{data?.images?[0]?.url or "this needs a default url"}" title="#{data.title or "untitled"}"/></a>
              </div>
              <div class="preview_text">
               <a class="preview_text_link" target="_blank" href="#{data.url or url}">
                <div class="preview_title">#{data.title or "untitled"}</div>
                <div class="provider_info">Provided by <strong>#{data.provider_name or "the internet"}</strong>#{if data.provider_url then " at <strong>"+data.provider_display+"</strong>" else ""}</div>
                <div class="description">#{data.description or ""}</div>
               </a>
              </div>
          """
        when "error" then return "There was an error"
        else
          log "EmbedBox encountered an unhandled content type '#{type}' - please implement a population method."

      @$("div.embed").html html
      @$("div.embed").addClass "custom-"+type

    else if data?.safe is no
      log "There was unsafe content.",data,data?.safe_type,data?.safe_message
      @hide()
    else
      log "Error!"

  embedExistingData:(data={},options={},callback=noop)=>
    unless data.type is "error" then @clearEmbed()
    @populateEmbed data
    @show()
    callback data

  embedUrl:(url,options={},callback=noop)=>
    @fetchEmbed url, options, (data,embedlyOptions)=>
      unless data.type is "error" then @clearEmbed()
      @populateEmbed data, url, embedlyOptions
      @show()
      callback data

  pistachio:->
    """
      {{> @settingsButton}}
      {{> @embedLoader}}
      <div class="link-embed clearfix">
        <div class="embed"></div>
      </div>
    """