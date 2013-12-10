class ActivityListItemView extends KDListItemView

  getActivityChildConstructors = ->
    JStatusUpdate       : StatusActivityItemView
    JCodeSnip           : CodesnipActivityItemView
    JQuestionActivity   : QuestionActivityItemView
    JDiscussion         : DiscussionActivityItemView
    JLink               : LinkActivityItemView
    JTutorial           : TutorialActivityItemView
    JBlogPost           : BlogPostActivityItemView

    NewMemberBucketData   : NewMemberBucketView

  getActivityChildCssClass = ->

    CFollowerBucket           : "system-message"
    CFolloweeBucket           : "system-message"
    CNewMemberBucket          : "system-message"
    CInstallerBucket          : "system-message"

    CFollowerBucketActivity   : "system-message"
    CFolloweeBucketActivity   : "system-message"
    CNewMemberBucketActivity  : "system-message"
    CInstallerBucketActivity  : "system-message"
    NewMemberBucketData       : "system-message"

  getBucketMap =->
    JAccount  : AccountFollowBucketItemView
    JTag      : TagFollowBucketItemView
    JApp      : AppFollowBucketItemView

  constructor:(options = {},data)->

    options.type = "activity"

    super options, data

    {constructorName} = data.bongo_
    @setClass getActivityChildCssClass()[constructorName]

    @bindTransitionEnd()

  viewAppended:->
    @addChildView @getData()

  addChildView:(data, callback)->
    # return
    return unless data?.bongo_
    {constructorName} = data.bongo_

    childConstructor =
      if /^CNewMemberBucket$/.test constructorName
        NewMemberBucketItemView
        # KDView
      else if /Bucket$/.test constructorName
        getBucketMap()[data.sourceName]
      else
        getActivityChildConstructors()[constructorName]

    if childConstructor
      childView = new childConstructor
        delegate : @
      , data
      @addSubView childView
      callback?()

  partial:-> ''

  show:(callback)->

    @getData().fetchTeaser? (err, teaser)=>
      if teaser
        @addChildView teaser, => @slideIn()

  slideIn:(callback=noop)->
    @once 'transitionend', callback.bind this
    @unsetClass 'hidden-item'

  slideOut:(callback=noop)->
    @once 'transitionend', callback.bind this
    @setClass 'hidden-item'
