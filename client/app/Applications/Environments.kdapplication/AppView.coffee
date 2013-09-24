class EnvironmentsMainView extends JView

  viewAppended:->

    @addSubView new HeaderViewSection type : "big", title : "Environments"
    @addSubView scene = new EnvironmentScene

    domainsContainer  = new EnvironmentDomainContainer
    scene.addContainer domainsContainer

    machinesContainer = new EnvironmentMachineContainer
    scene.addContainer machinesContainer, x: 300

    scene.whenItemsLoadedFor [domainsContainer, machinesContainer], =>
      log "All Loaded", domainsContainer, machinesContainer
      for _, machine of machinesContainer.dias
        log "Looking for machine...", machine
        for _, domain of domainsContainer.dias
          log "Looking for domain...", domain
          if domain.data.aliases and machine.data.title in domain.data.aliases
            scene.connect \
              {dia : domain , joint : 'right', container: domainsContainer}, \
              {dia : machine, joint : 'left',  container: machinesContainer}


#  - DO NOT TOUCH BELOW

#   tabData = [
#     name        : 'Domains'
#     viewOptions :
#       viewClass : DomainsMainView
#   ,
#     name        : 'VMS'
#     viewOptions :
#       viewClass : VMsMainView
#   ,
#     name        : 'Kites'
#     viewOptions :
#       viewClass : KDView
#   ,
#     name        : 'Builder'
#     viewOptions :
#       viewClass : EnvironmentScene
#   ]

#   navData =
#     title : "Settings"
#     items : ({title:item.name, hiddenHandle:'hidden'} for item in tabData)

#   constructor:(options = {}, data = {})->
#     super options, data

#     @header = new HeaderViewSection type : "big", title : "Environments"

#     # * see the note below *
#     @nav = new KDView
#       tagName  : "ul"
#       cssClass : "kdlistview kdlistview-default"

#     @utils.defer => @nav.unsetClass "kdtabhandlecontainer"

#     @tabs   = new KDTabView
#       cssClass           : 'environment-content'
#       tabHandleContainer : @nav
#       tabHandleClass     : EnvironmentsTabHandleView
#     , data

#     @listenWindowResize()

#     @once 'viewAppended', =>
#       @createTabs()
#       @_windowDidResize()

#   createTabs:->
#     for {name, viewOptions}, i in tabData
#       @tabs.addPane (new KDTabPaneView {name, viewOptions}), i is 0

#   _windowDidResize:->
#     contentHeight = @getHeight() - @header.getHeight()
#     @$('>section, >aside').height contentHeight

#   pistachio:->
#     """
#       {{> @header}}
#       <aside class='fl'>
#         <div class="kdview common-inner-nav">
#           <div class="kdview listview-wrapper list">
#             <h4 class="kdview kdheaderview list-group-title"><span>MANAGE</span></h4>
#             {{> @nav}}
#           </div>
#         </div>
#       </aside>
#       <section class='right-overflow'>
#         {{> @tabs}}
#       </section>
#     """

# # take this to its own file - SY

# class EnvironmentsTabHandleView extends KDTabHandleView

#   constructor:(options={}, data)->
#     # * see the note below *
#     options.tagName  = 'li'
#     options.closable = no
#     options.cssClass = 'kdview kdlistitemview kdlistitemview-default'

#     super options, data

#     @unsetClass 'kdtabhandle'

#   click: do->
#     notification = null
#     ->
#       unless @getOptions().title is "Domains"
#         notification?.destroy()
#         notification = new KDNotificationView title : 'Coming soon...'
#         return no


#   partial:-> "<a href='#'>#{@getOptions().title or 'Default Title'}</a>"

# # * quick hack: don't copy/paste from here :)
# #   faking a listitem to be able to use same styles
# #   very narrow usage this is acceptable under the circumstances. SY
