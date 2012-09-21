class ActivityUpdateWidgetController extends KDViewController

  # WIP: stop submission if user wants to submit stuff too often

  submissionStopped = no

  notifySubmissionStopped = ->

    # new KDNotificationView type : "mini", title : "Please take a little break!"

  stopSubmission = ->
    # submissionStopped = yes
    # __utils.wait 20000, -> submissionStopped = no

  loadView:(mainView)->

    mainView.addWidgetPane
      paneName    : "update"
      mainContent : updateWidget = new ActivityStatusUpdateWidget
        cssClass  : "status-widget"
        callback  : (formData)=>
          if submissionStopped
            return notifySubmissionStopped()
          else
            @updateWidgetSubmit formData, stopSubmission
            updateWidget.switchToSmallView()
            mainView.resetWidgets()

    mainView.addWidgetPane
      paneName    : "question"
      mainContent : questionWidget = new ActivityQuestionWidget
        callback  : @questionWidgetSubmit

    codeSnippetPane = mainView.addWidgetPane
      paneName    : "codesnip"
      mainContent : codeWidget = new ActivityCodeSnippetWidget
        delegate  : mainView
        callback  : (data)=>
          if submissionStopped
            return notifySubmissionStopped()
          else
            @codeSnippetWidgetSubmit data, stopSubmission
            mainView.resetWidgets()

    codeSharePane = mainView.addWidgetPane
      paneName    : "codeshare"
      mainContent : codeShareWidget = new ActivityCodeShareWidget
        delegate  : mainView
        callback  : (data)=>
          if submissionStopped
            return notifySubmissionStopped()
          else

            # this forces the iframe to load the code and execute it
            codeShareWidget.codeShareResultView.hide()
            codeShareWidget.codeShareResultView.emit "CodeShareSourceHasChanges", data

            # reset widget tab as if it was submitted
            mainView.resetWidgets()

            # notify the user
            notifiy = new KDNotificationView
              title: "Submitting your Code Share"
              content: "This may take up to ten seconds. Thank you for your patience!"
              duration: 5000

            # then wait x seconds
            window.setTimeout =>
              #only if the browser/tab did not lock up due to script execution, this will run
              @codeShareWidgetSubmit data, stopSubmission
            , 5000

    mainView.addWidgetPane
      paneName    : "link"
      mainContent : linkWidget = new ActivityLinkWidget
        callback  : @linkWidgetSubmit

    mainView.addWidgetPane
      paneName    : "tutorial"
      mainContent : tutorialWidget = new ActivityTutorialWidget
        callback  : @tutorialWidgetSubmit

    mainView.addWidgetPane
      paneName    : "discussion"
      mainContent : discussionWidget = new ActivityDiscussionWidget
        delegate  : mainView
        callback  : (data)=>
          if submissionStopped
            return notifySubmissionStopped()
          else
            @discussionWidgetSubmit data, stopSubmission
            mainView.resetWidgets()

    mainView.showPane "update"

    codeSnippetPane.on 'PaneDidShow', -> codeWidget.widgetShown()

    # THIS WILL DISABLE CODE SHARES
    # codeSharePane.on 'PaneDidShow', -> codeShareWidget.widgetShown()

    @getSingleton('mainController').on "ActivityItemEditLinkClicked", (activity)=>
      # Remove this if can fix the ActivityStatusUpdateWidget's bug
      appManager.openApplication "Activity"
      mainView.setClass "edit-mode"

      switch activity.bongo_.constructorName
        when "JStatusUpdate"
          mainView.showPane "update"
          updateWidget.switchToEditView activity
        when "JCodeSnip"
          mainView.showPane "codesnip"
          codeWidget.switchToEditView activity
        when "JDiscussion"
          mainView.showPane "discussion"
          discussionWidget.switchToEditView activity
        # THIS WILL DISABLE CODE SHARES
        # when "JCodeShare"
        #   mainView.showPane "codeshare"
        #   codeShareWidget.switchToEditView activity

    @getSingleton('mainController').on "ContentDisplayItemForkLinkClicked", (activity)=>
      mainView.setClass "edit-mode"

      switch activity.bongo_.constructorName
        when "JCodeShare"
          mainView.showPane "codeshare"
          codeShareWidget.switchToForkView activity

  updateWidgetSubmit:(data, callback)->

    # if troll clear the tag input
    data.meta?.tags = [] if KD.checkFlag 'exempt'

    if data.activity
      {activity} = data
      delete data.activity
      activity.modify data, (err, res)=>
        callback? err, res
        unless err
          new KDNotificationView type : "mini", title : "Updated successfully"
        else
          new KDNotificationView type : "mini", title : err.message
    else
      KD.remote.api.JStatusUpdate.create data, (err, activity)=>
        callback? err, activity
        unless err
          @propagateEvent (KDEventType:"OwnActivityHasArrived"), activity
        else
          new KDNotificationView type : "mini", title : "There was an error, try again later!"

  codeSnippetWidgetSubmit:(data, callback)->
    if data.activity
      {activity} = data
      delete data.activity
      activity.modify data, (err, res)=>
        callback? err, res
        unless err
          new KDNotificationView type : "mini", title : "Updated successfully"
        else
          new KDNotificationView type : "mini", title : err.message
    else
      if submissionStopped
        return notifySubmissionStopped()
      KD.remote.api.JCodeSnip.create data, (err, codesnip) =>
        callback? err, codesnip
        stopSubmission()
        if err
          new KDNotificationView type : "mini", title : "There was an error, try again later!"
        else
          @propagateEvent (KDEventType:"OwnActivityHasArrived"), codesnip

  # THIS WILL DISABLE CODE SHARES
  # codeShareWidgetSubmit:(data, callback)->
  #   if data.activity
  #     {activity} = data
  #     delete data.activity
  #     activity.modify data, (err, res)=>
  #       callback? err, res
  #       unless err
  #         new KDNotificationView type : "mini", title : "Updated successfully"
  #       else
  #         new KDNotificationView type : "mini", title : err.message
  #   else
  #     if submissionStopped
  #       return notifySubmissionStopped()
  #     bongo.api.JCodeShare.create data, (err, codeshare) =>
  #       callback? err, codeshare
  #       stopSubmission()
  #       if err
  #         new KDNotificationView type : "mini", title : "There was an error, try again later!"
  #       else
  #         @propagateEvent (KDEventType:"OwnActivityHasArrived"), codeshare


  questionWidgetSubmit:(data)->
    log 'creating question', data
    KD.remote.api.JActivity.create {type: 'qa', activity: data}, (error) ->
      warn 'couldnt ask question', error if error

  linkWidgetSubmit:(data)->
    log 'sharing link', data
    KD.remote.api.JActivity.create {type: 'link', activity: data}, (error) ->
      warn 'couldnt save link', error if error

  tutorialWidgetSubmit:(data)->
    log 'sharing tutorial', data
    KD.remote.api.JActivity.create {type: 'tutorial', activity: data}, (error) ->
      warn 'couldnt save tutorial', error if error

  discussionWidgetSubmit:(data, callback)->
    if data.activity
      {activity} = data
      delete data.activity
      activity.modify data, (err, res)=>
        callback? err, res
        unless err
          new KDNotificationView type : "mini", title : "Updated the discussion successfully"
        else
          new KDNotificationView type : "mini", title : err.message
    else
      if submissionStopped
        return notifySubmissionStopped()
      KD.remote.api.JDiscussion.create data, (err, discussion) =>
        callback? err, discussion
        stopSubmission()
        if err
          new KDNotificationView type : "mini", title : "There was an error, try again later!"
        else
          @propagateEvent (KDEventType:"OwnActivityHasArrived"), discussion

