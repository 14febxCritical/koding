class ActivityItemChild extends KDView

  constructor:(options, data)->

    origin =
      constructorName  : data.originType
      id               : data.originId

    @avatar = new AvatarView {
      size    : {width: 40, height: 40}
      origin
    }

    @author = new ProfileLinkView { origin }

    @tags = new ActivityChildViewTagGroup
      itemsToShow   : 3
      subItemClass  : TagLinkView
    , data.tags


    # for discussion, switch to the View that supports nested structures
    # JDiscussion
    # -> JOpinion
    #    -> JComment
    if data.bongo_.constructorName is "JDiscussion"
      @commentBox = new OpinionView null, data
    else
      @commentBox = new CommentView null, data

    @actionLinks = new ActivityActionsView delegate : @commentBox.commentList, cssClass : "comment-header", data

    account = KD.whoami()
    if (data.originId is KD.whoami().getId()) or KD.checkFlag 'super-admin'
      @settingsButton = new KDButtonViewWithMenu
        cssClass    : 'transparent activity-settings-context activity-settings-menu'
        title       : ''
        icon        : yes
        delegate    : @
        iconClass   : "arrow"
        menu        : @settingsMenu data
        callback    : (event)=> @settingsButton.contextMenu event
    else
      @settingsButton = new KDCustomHTMLView tagName : 'span', cssClass : 'hidden'

    super

    data = @getData()
    data.on 'TagsChanged', (tagRefs)=>
      KD.remote.cacheable tagRefs, (err, tags)=>
        @getData().setAt 'tags', tags
        @tags.setData tags
        # debugger
        @tags.render()

    data.on 'PostIsDeleted', =>
      if KD.whoami().getId() is data.getAt('originId')
        @parent.destroy()
      else
        @parent.putOverlay
          isRemovable : no
          parent      : @parent
          cssClass    : 'half-white'

    data.watch 'repliesCount', (count)=>
      @commentBox.decorateCommentedState() if count >= 0

    @contentDisplayController = @getSingleton "contentDisplayController"

    KD.remote.cacheable data.originType, data.originId, (err, account)=>
      @setClass "exempt" if account and KD.checkFlag 'exempt', account

  settingsMenu:(data)->

    account = KD.whoami()

    menu = [
      type      : "contextmenu"
      items     : []
    ]

    if data.originId is KD.whoami().getId()
      menu[0].items = [
        { title : 'Edit',   id : 1,  parentId : null, callback : => @getSingleton('mainController').emit 'ActivityItemEditLinkClicked', data }
        { title : 'Delete', id : 2,  parentId : null, callback : => @confirmDeletePost data  }
      ]

      return menu

    if KD.checkFlag 'super-admin'
      menu[0].items = [
        { title : 'MARK USER AS TROLL', id : 1,  parentId : null, callback : => @getSingleton('mainController').markUserAsTroll data  }
        { title : 'UNMARK USER AS TROLL', id : 1,  parentId : null, callback : => @getSingleton('mainController').unmarkUserAsTroll data  }
        { title : 'Delete Post', id : 3,  parentId : null, callback : => @confirmDeletePost data  }
      ]

      return menu


  confirmDeletePost:(data)->

    modal = new KDModalView
      title          : "Delete post"
      content        : "<div class='modalformline'>Are you sure you want to delete this post?</div>"
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
              unless err then @emit 'ActivityIsDeleted'
              else new KDNotificationView
                type     : "mini"
                cssClass : "error editor"
                title     : "Error, please try again later!"

  click:(event)->

    $trg = $(event.target)
    more = "span.collapsedtext a.more-link"
    less = "span.collapsedtext a.less-link"
    $trg.parent().addClass("show").removeClass("hide") if $trg.is(more)
    $trg.parent().removeClass("show").addClass("hide") if $trg.is(less)

