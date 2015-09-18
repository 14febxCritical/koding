kd                 = require 'kd'
globals            = require 'globals'
KDCustomHTMLView   = kd.CustomHTMLView

EnvironmentsModal  = require 'app/environment/environmentsmodal'
SidebarMachineList = require './sidebarmachinelist'


module.exports = class SidebarOwnMachinesList extends SidebarMachineList

  constructor: (options = {}, data) ->

    options.title      ?= 'Your VMs'
    options.hasPlusIcon = yes
    options.cssClass    = 'my-machines'

    super options, data


  viewAppended: ->

    super

    @header.addSubView @unreadCount = new KDCustomHTMLView
      tagName  : 'cite'
      cssClass : 'count hidden'
      partial  : '1'

    kd.singletons.computeController.on 'StackRevisionChecked', (stack) =>

      return  if @isDestroyed # This needs to be investigated ~ GG
                              # We're creating instances of this multiple times
                              # but somehow we're not cleaning up them correctly

      {_revisionStatus} = stack
      if not _revisionStatus?.error? and {status} = _revisionStatus
        @unreadCount.show()  if status?.code > 0


  headerClickHandler: -> new EnvironmentsModal
