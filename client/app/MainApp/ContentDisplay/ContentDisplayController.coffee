class ContentDisplayController extends KDController

  constructor:(options)->
    super
    @displays = {}
    @attachListeners()
    @revivedContentDisplay = no

  attachListeners:->
    @on "ContentDisplayWantsToBeShown",  (view)=> @showContentDisplay view
    @on "ContentDisplayWantsToBeHidden", (view)=> @hideContentDisplay view
    @on "ContentDisplaysShouldBeHidden",       => @hideAllContentDisplays()
    KD.getSingleton("appManager").on "ApplicationShowedAView",    => @hideAllContentDisplays()

  showContentDisplay:(view)->
    contentPanel = @getSingleton "contentPanel"
    wrapper = new ContentDisplay
      domId : "content-display-wrapper" if not @revivedContentDisplay
    wrapper.bindTransitionEnd()
    @displays[view.id] = view
    wrapper.addSubView view
    contentPanel.addSubView wrapper
    @slideWrapperIn wrapper
    @revivedContentDisplay = yes
    return wrapper

  hideContentDisplay:(view)-> history.back()

  hideAllContentDisplays:(exceptFor)->
    displayIds =\
      if exceptFor?
        (id for own id,display of @displays when exceptFor isnt display)
      else
        (id for own id,display of @displays)

    return if displayIds.length is 0

    lastId = displayIds.pop()
    for id in displayIds
      @destroyView @displays[id]

    @slideWrapperOut @displays[lastId]

  slideWrapperIn:(wrapper)->
    wrapper.setClass 'in'

  slideWrapperOut:(view)->
    wrapper = view.parent
    wrapper.once 'transitionend', => @destroyView view
    wrapper.unsetClass 'in'

  destroyView:(view)->
    wrapper = view.parent
    @emit 'ContentDisplayIsDestroyed', view
    delete @displays[view.id]
    view.destroy()
    wrapper.destroy()
