class StatusActivityItemView extends ActivityItemChild

  constructor:(options = {}, data)->

    options.cssClass or= "activity-item status"
    options.tooltip  or=
      title            : "Status Update"
      selector         : "span.type-icon"
      offset           : 3

    super options,data

  viewAppended:()->

    return if @getData().constructor is bongo.api.CStatusActivity

    super

    @setTemplate @pistachio()
    @template.update()

  click:(event)->

    super

    if $(event.target).is("[data-paths~=body]")
      appManager.tell "Activity", "createContentDisplay", @getData()

  applyTextExpansions:(str = "")-> @utils.applyTextExpansions str, yes

  pistachio:->
    """
    {{> @settingsButton}}
    <span class="avatar">{{> @avatar}}</span>
    <div class='activity-item-right-col'>
      <h3 class='hidden'></h3>
      <p>{{@applyTextExpansions #(body)}}</p>
      <footer class='clearfix'>
        <div class='type-and-time'>
          <span class='type-icon'></span> by {{> @author}}
          <time>{{$.timeago #(meta.createdAt)}}</time>
          {{> @tags}}
        </div>
        {{> @actionLinks}}
      </footer>
      {{> @commentBox}}
    </div>
    """