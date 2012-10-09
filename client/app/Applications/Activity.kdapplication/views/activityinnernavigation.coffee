class ActivityInnerNavigation extends CommonInnerNavigation
  viewAppended:()->

    feedController = @setListController
      type : "feed"
      itemClass : ListGroupShowMeItem
    , @feedMenuData
    @addSubView feedController.getView()
    feedController.selectItem feedController.getItemsOrdered()[0]

    filterController = @setListController
      type : "showme"
      itemClass : ListGroupShowMeItem
    , @showMenuData
    @addSubView filterController.getView()
    filterController.selectItem filterController.getItemsOrdered()[0]

    @addSubView helpBox = new HelpBox
      subtitle    : "About Your Activity Feed"
      tooltip     :
        title     : "<p class=\"bigtwipsy\">The Activity feed displays posts from the people and topics you follow on Koding. It's also the central place for sharing updates, code, links, discussions and questions with the community. </p>"
        placement : "above"
        offset    : 0
        delayIn   : 300
        html      : yes
        animate   : yes

  feedMenuData :
    title : "FEED"
    items : [
        { title : "Public"  , type : "public" }
        { title : "Followed", type : "private" }
      ]

  showMenuData :
    title : "SHOW ME"
    items : [
        { title : "Everything" }
        { title : "Status Updates",   type : "CStatusActivity" }
        { title : "Code Snippets",    type : "CCodeSnipActivity" }
        { title : "Q&A",              type : "qa",         disabledForBeta : yes }
        { title : "Discussions",      type : "CDiscussionActivity" }
        { title : "Links",            type : "CLinkActivity" }
        # { title : "Code Shares",      type : "codeshare", disabledForBeta : yes }
        # { title : "Commits",          type : "commit", disabledForBeta : yes }
        # { title : "Projects",         type : "newproject", disabledForBeta : yes }
      ]
