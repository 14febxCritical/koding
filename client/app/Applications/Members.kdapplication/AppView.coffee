class MembersMainView extends KDView

  createCommons:->

    @addSubView @header = new HeaderViewSection
      type  : "big"
      title : "Members"

    KD.getSingleton("mainController").on 'AccountChanged', @bound 'setSearchInput'
    @setSearchInput()

  setSearchInput:->
    @header.setSearchInput()  if 'list members' in KD.config.permissions

class MembersListItemView extends KDListItemView
  constructor:(options, data)->

    options = options ? {}
    options.type = "members"
    options.avatarSizes or= [60, 60] # [width, height]

    super options,data

    memberData = @getData()
    options    = @getOptions()

    @avatar = new AvatarView
      size:
        width: options.avatarSizes[0]
        height: options.avatarSizes[1]
    , memberData

    if (memberData.profile.nickname is KD.whoami().profile.nickname) or \
        memberData.type is 'unregistered'
    then @followButton = new KDView
    else @followButton = new MemberFollowToggleButton
      style       : "follow-btn"
      loader      :
        color     : "#333333"
        diameter  : 18
        top       : 11
    , memberData

    memberData.locationTags or= []
    if memberData.locationTags.length < 1
      memberData.locationTags[0] = "Earth"

    @location     = new KDCustomHTMLView
      partial     : memberData.locationTags[0]
      cssClass    : "location"

    @profileLink = new ProfileLinkView {}, memberData
    @profileLink.render()

  click:(event)->
    KD.utils.showMoreClickHandler.call this, event
    targetATag = $(event.target).closest('a')
    if targetATag.is(".followers") and parseInt(targetATag.text()) isnt 0
      KD.getSingleton('router').handleRoute "/#{@getData().profile.nickname}/Followers"
    else if targetATag.is(".following") and parseInt(targetATag.text()) isnt 0
      KD.getSingleton('router').handleRoute "/#{@getData().profile.nickname}/Following"

  clickOnMyItem:(event)->
    if $(event.target).is ".propagateProfile"
      @emit "VisitorProfileWantsToBeShown", {content : @getData(), contentType : "member"}

  viewAppended:->
    @setClass "member-item"
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
      <span>
        {{> @avatar}}
      </span>

      <div class='member-details'>
        <header class='personal'>
          <h3>{{> @profileLink}}</h3> <span>{{> @location}}</span>
        </header>

        <p>{{ @utils.applyTextExpansions #(profile.about), yes}}</p>

        <footer>
          <span class='button-container'>{{> @followButton}}</span>
          <a class='followers' href='#'> <cite></cite> {{#(counts.followers)}} Followers</a>
          <a class='following' href='#'> <cite></cite> {{#(counts.following)}} Following</a>
          <time class='timeago hidden'>
            <span class='icon'></span>
            <span>
              Active <cite title='{{#(meta.modifiedAt)}}'></cite>
            </span>
          </time>
        </footer>

      </div>
    """


class MembersLocationView extends KDCustomHTMLView
  constructor: (options, data) ->
    options = $.extend {tagName: 'p', cssClass: 'place'}, options
    super options, data

  viewAppended: ->
    locations = @getData()
    @setPartial locations?[0] or ''

class MembersLikedContentDisplayView extends KDView

  constructor:(options = {}, data)->

    options.view     or= mainView = new KDView
    options.cssClass or= 'member-followers content-page-members'

    super options, data

  createCommons:(account)->

    name = KD.utils.getFullnameFromAccount account

    contentDisplayController = KD.getSingleton "contentDisplayController"
    headerTitle              = "Activities which #{name} liked"

    @addSubView header = new HeaderViewSection
      type  : "big"
      title : headerTitle

    @addSubView subHeader = new KDCustomHTMLView
      tagName  : "h2"
      cssClass : 'sub-header'

    subHeader.addSubView backLink = new KDCustomHTMLView
      tagName : "a"
      partial : "<span>&laquo;</span> Back"
      click   : => contentDisplayController.emit "ContentDisplayWantsToBeHidden", @

    @listenWindowResize()



class MembersContentDisplayView extends KDView
  constructor:(options={}, data)->
    options = $.extend
      view : mainView = new KDView
      cssClass : 'member-followers content-page-members'
    ,options

    super options, data

  createCommons:(account, filter)->

    name = KD.utils.getFullnameFromAccount account

    if filter is "following"
    then title = "Members who #{name} follows"
    else title = "Members who follow #{name}"

    @addSubView header = new HeaderViewSection {type : "big", title}

    @addSubView subHeader = new KDCustomHTMLView
      tagName  : "h2"
      cssClass : 'sub-header'

    subHeader.addSubView backLink = new KDCustomHTMLView
      tagName : "a"
      partial : "<span>&laquo;</span> Back"
      click   : (event)=>
        event.preventDefault()
        event.stopPropagation()
        KD.getSingleton('contentDisplayController').emit "ContentDisplayWantsToBeHidden", @

    @listenWindowResize()
