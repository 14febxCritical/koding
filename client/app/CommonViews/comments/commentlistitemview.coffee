class CommentListItemView extends KDListItemView
  constructor:(options,data)->

    options.type     or= "comment"
    options.cssClass or= "kdlistitemview kdlistitemview-comment"

    super options,data

    data = @getData()

    originId    = data.getAt('originId')
    originType  = data.getAt('originType')
    deleterId   = data.getAt('deletedBy')?.getId?()

    origin =
      constructorName  : originType
      id               : originId

    @avatar = new AvatarView {
      size     :
        width  : options.avatarWidth or 30
        height : options.avatarHeight or 30
      origin
    }

    @author = new ProfileLinkView { origin }

    if deleterId? and deleterId isnt originId
      @deleter = new ProfileLinkView {}, data.getAt('deletedBy')

    @deleteLink = new KDCustomHTMLView
      tagName     : 'a'
      attributes  :
        href      : '#'
      cssClass    : 'delete-link hidden'

    activity = @getDelegate().getData()
    bongo.cacheable data.originId, "JAccount", (err, account)=>
      loggedInId = KD.whoami().getId()
      if loggedInId is data.originId or       # if comment/review owner
         loggedInId is activity.originId or   # if activity/app owner
         KD.checkFlag "super-admin", account  # if super-admin
        @deleteLink.unsetClass "hidden"
        @listenTo
          KDEventTypes       : "click"
          listenedToInstance : @deleteLink
          callback           : => @confirmDeleteComment data

    @likeView = new LikeViewClean { tooltipPosition : 'sw' }, data

  render:->
    if @getData().getAt 'deletedAt'
      @emit 'CommentIsDeleted'
    @updateTemplate()
    super

  viewAppended:->
    @updateTemplate yes
    @template.update()

  click:(event)->

    if $(event.target).is("span.collapsedtext a.more-link")
      @$("span.collapsedtext").addClass "show"
      @$("span.collapsedtext").removeClass "hide"

    if $(event.target).is("span.collapsedtext a.less-link")
      @$("span.collapsedtext").removeClass "show"
      @$("span.collapsedtext").addClass "hide"

    if $(event.target).is "span.avatar a, a.user-fullname"
      {originType, originId} = @getData()
      bongo.cacheable originType, originId, (err, origin)->
        unless err
          appManager.tell "Members", "createContentDisplay", origin

  confirmDeleteComment:(data)->
    {type} = @getOptions()
    modal = new KDModalView
      title          : "Delete #{type}"
      content        : "<div class='modalformline'>Are you sure you want to delete this #{type}?</div>"
      height         : "auto"
      overlay        : yes
      buttons        :
        Delete       :
          style      : "modal-clean-red"
          loader     :
            color    : "#ffffff"
            diameter : 16
          callback   : =>
            data.delete (err)=>
              modal.buttons.Delete.hideLoader()
              modal.destroy()
              # unless err then @emit 'CommentIsDeleted'
              # else
              if err then new KDNotificationView
                type     : "mini"
                cssClass : "error editor"
                title    : "Error, please try again later!"

  updateTemplate:(force = no)->
    if @getData().getAt 'deletedAt'
      {type} = @getOptions()
      @setClass "deleted"
      if @deleter
        @setTemplate "<div class='item-content-comment clearfix'><span>{{> @author}}'s #{type} has been deleted by {{> @deleter}}.</span></div>"
      else
       @setTemplate "<div class='item-content-comment clearfix'><span>{{> @author}}'s #{type} has been deleted.</span></div>"
    else if force
      @setTemplate @pistachio()

  pistachio:->
    """
    <div class='item-content-comment clearfix'>
      <span class='avatar'>{{> @avatar}}</span>
      <div class='comment-contents clearfix'>
        <p class='comment-body'>
          {{> @author}}
          {{@utils.applyTextExpansions #(body), yes}}
        </p>
        {{> @deleteLink}}
        <time>{{$.timeago #(meta.createdAt)}}</time>
        {{> @likeView}}
      </div>
    </div>
    """
