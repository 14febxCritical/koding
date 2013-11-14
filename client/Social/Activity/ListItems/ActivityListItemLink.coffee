class LinkActivityItemView extends ActivityItemChild

  constructor:(options = {}, data)->

    options.cssClass or= "activity-item link"
    options.tooltip  or=
      title            : "Link"
      selector         : "span.type-icon"
      offset           : 3

    super options,data

    embedOptions = $.extend {}, options,
      delegate    : this
      hasDropdown : no

    @embedBox = new EmbedBox embedOptions, data

    @timeAgoView = new KDTimeAgoView {}, @getData().meta.createdAt

  viewAppended:->
    return if @getData().constructor is KD.remote.api.CLinkActivity
    super()
    @setTemplate @pistachio()
    @template.update()

    if @getData().link_embed?
      @embedBox.embedExistingData @getData().link_embed
    else if @getData().link_url?
      embedBox.embedUrl @getData().link_url
    else log "There is no link information to embed."

  # click:(event)->

  #   super

  #   if $(event.target).is("[data-paths~=body]")
  #     KD.getSingleton("appManager").tell "Activity", "createContentDisplay", @getData()

  applyTextExpansions:(str = "")-> @utils.applyTextExpansions str, yes

  pistachio:->
    """
    {{> @settingsButton}}
    <span class="avatar">{{> @avatar}}</span>
    <div class='activity-item-right-col'>
      <h3 class='hidden'></h3>
      <h3><a href="#{@getData().link_url or "#"}" target="_blank">{{@applyTextExpansions #(title)}}</a></h3>
      <p>{{@applyTextExpansions #(body)}}</p>
      {{> @embedBox}}
      <footer class='clearfix'>
        <div class='type-and-time'>
          <span class='type-icon'></span>{{> @contentGroupLink }} by {{> @author}}
          {{> @timeAgoView}}
          {{> @tags}}
        </div>
        {{> @actionLinks}}
      </footer>
      {{> @commentBox}}
    </div>
    """
