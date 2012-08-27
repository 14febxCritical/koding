class MessagesListItemView extends KDListItemView
  constructor:(options, data)->
    super

  partial:(data)->
    "<div>#{data.subject or '(No title)'}</div>"

class MessagesListView extends KDListView

class MessagesListController extends KDListViewController

  constructor:(options, data)->
    options.subItemClass or= InboxMessagesListItem
    options.listView     or= new MessagesListView

    super options, data

    @getListView().registerListener
      KDEventTypes  : "AvatarPopupShouldBeHidden"
      listener      : @
      callback      : =>
        @propagateEvent KDEventType : 'AvatarPopupShouldBeHidden'

  fetchMessages:(callback)->
    appManager.tell 'Inbox', 'fetchMessages',
      as          : 'recipient'
      limit       : 3
      sort        :
        timestamp : -1
    , (err, messages)=>
      # @propagateEvent KDEventType : "ClearMessagesListLoaderTimeout"
      @removeAllItems()
      @instantiateListItems messages

      unreadCount = 0
      for message in messages
        unreadCount++ unless message.flags_?.read

      @emit "MessageCountDidChange", unreadCount
      callback? err,messages

  fetchNotificationTeasers:(callback)->
    KD.whoami().fetchActivityTeasers? {
      targetName: $in: [
        'CReplieeBucketActivity'
        'CFolloweeBucketActivity'
        'CLikeeBucketActivity'
      ]
    }, {
      limit: 8
      sort:
        timestamp: -1
    }, (err, items)=>
      if err
        warn "There was a problem fetching notifications!",err
      else
        unglanced = items.filter (item)-> item.getFlagValue('glanced') isnt yes
        @emit 'NotificationCountDidChange', unglanced.length
        callback? items

class NotificationListItem extends KDListItemView

  activityNameMap = ->
    JStatusUpdate   : "your status update."
    JCodeSnip       : "your status update."
    JAccount        : "started following you."
    JPrivateMessage : "your private message."

  bucketNameMap = ->
    CReplieeBucketActivity  : "comment"
    CFolloweeBucketActivity : "follow"
    CLikeeBucketActivity    : "like"

  actionPhraseMap = ->
    comment : "commented on"
    reply   : "replied to"
    like    : "liked"
    follow  : ""
    share   : "shared"
    commit  : "committed"

  constructor:(options = {}, data)->

    options.tagName        or= "li"
    options.linkGroupClass or= LinkGroup
    options.avatarClass    or= AvatarView

    super options, data

    @setClass bucketNameMap()[data.bongo_.constructorName]

    @snapshot = JSON.parse Encoder.htmlDecode data.snapshot

    # group = data.map (participant)->
    #   constructorName : participant.targetOriginName
    #   id              : participant.targetOriginId

    {group} = @snapshot

    @participants = new options.linkGroupClass {group}
    @avatar       = new options.avatarClass
      size     :
        width  : 40
        height : 40
      origin   : group[0]

  viewAppended:->
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
      <div class='avatar-wrapper fl'>
        {{> @avatar}}
      </div>
      <div class='right-overflow'>
        <p>{{> @participants}} {{@getActionPhrase #(dummy)}} {{@getActivityPlot #(dummy)}}</p>
        <footer>
          <time>{{$.timeago @getLatestTimeStamp #(dummy)}}</time>
        </footer>
      </div>
    """

  getLatestTimeStamp:()->
    data = @getData()
    # lastUpdateAt = @snapshot.group[@snapshot.group.length-1]
    lastUpdateAt = @snapshot.group.modifiedAt
    return lastUpdateAt or data.createdAt

  getActionPhrase:()->
    data = @getData()
    if @snapshot.anchor.constructorName is "JPrivateMessage"
      @unsetClass "comment"
      @setClass "reply"
      actionPhraseMap().reply
    else
      actionPhraseMap()[bucketNameMap()[data.bongo_.constructorName]]

  getActivityPlot:()->
    data = @getData()
    return activityNameMap()[@snapshot.anchor.constructorName]

  click:->

    if @snapshot.anchor.constructorName is "JPrivateMessage"
      appManager.openApplication "Inbox"
    else
      koding.api[@snapshot.anchor.constructorName].one _id : @snapshot.anchor.id, (err, post)->
        if post
          appManager.tell "Activity", "createContentDisplay", post
        else
          new KDNotificationView
            title : "This post has been deleted!"
            duration : 1000

    # {sourceName,sourceId} = @getData()[0]
    # contentDisplayController = @getSingleton('contentDisplayController')
    # list = @getDelegate()
    # list.propagateEvent KDEventType : 'AvatarPopupShouldBeHidden'
    # Bongo.cacheable sourceName, sourceId, (err, source)=>
    #   appManager.tell "Activity", "createContentDisplay", source
