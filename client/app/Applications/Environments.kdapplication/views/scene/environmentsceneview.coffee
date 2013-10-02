class EnvironmentScene extends KDDiaScene

  containerMap =
    EnvironmentDomainContainer  : 'domains'
    EnvironmentMachineContainer : 'machines'
  itemMap      =
    EnvironmentDomainItem       : 'domain'
    EnvironmentMachineItem      : 'machine'

  constructor:->
    super
      cssClass  : 'environments-scene'
      lineWidth : 1

    @boxes = {}

    sc = KD.getSingleton 'appStorageController'
    @appStorage = sc.storage 'EnvironmentsScene', '1.0'

  disconnect:(dia, joint)->

    removeConnection = => KDDiaScene::disconnect.call this, dia, joint
    targetConnection = @findTargetConnection dia, joint
    return unless targetConnection
    {source, target} = targetConnection

    items = parseItems source, target
    {domain, machine} = items
    return unless domain

    @askForApprove items, 'delete', (modal)=>
      return unless machine? # Remove a domain from a machine
      jDomain = domain.dia.data.domain # JDomain
      vmName  = machine.dia.data.title # JVM.hostnameAlias
      jDomain.unbindVM hostnameAlias: vmName, (err)=>
        modal.destroy()
        return KD.showError err  if err
        jDomain.hostnameAlias.splice jDomain.hostnameAlias.indexOf(vmName), 1
        removeConnection()

  connect:(source, target, internal = no)->

    createConnection = => KDDiaScene::connect.call this, source, target
    return createConnection()  if internal

    items = parseItems source, target
    {domain, machine} = items
    return unless domain

    if machine?
      if domain.dia.data.domain.hostnameAlias.length > 0
        return new KDNotificationView
          title : "A domain name can only be bound to one VM."

    @askForApprove items, 'create', (modal)=>
      if machine? # Assign a domain to a machine
        jDomain = domain.dia.data.domain # JDomain
        vmName  = machine.dia.data.title # JVM.hostnameAlias
        jDomain.bindVM hostnameAlias: vmName, (err)=>
          modal.destroy()
          return KD.showError err  if err
          jDomain.hostnameAlias.push vmName
          createConnection()

  updateConnections:->
    for _mkey, machine of @boxes.machines.dias
      for _dkey, domain of @boxes.domains.dias
        if domain.data.aliases and machine.data.title in domain.data.aliases
          @connect {dia : domain , joint : 'right'}, \
                   {dia : machine, joint : 'left' }, yes

  askForApprove:(items, action, callback)->
    return unless KD.isLoggedIn()
      new KDNotificationView
        title : "You need to login to change domain settings."

    modal = new EnvironmentApprovalModal {action}, items
    modal.once 'Approved', => callback modal

  whenItemsLoadedFor:do->
    # poor man's when/promise implementation ~ GG
    (containers, callback)->
      counter = containers.length
      containers.forEach (container)->
        container.once "DataLoaded", ->
          if counter is 1 then do callback
          counter--
        container.refreshItems()

  addContainer:(container, pos)->
    pos ?= x: 40 + @containers.length * 300, y: 40
    super container, pos

    {name} = container.constructor
    label  = containerMap[name] or name
    container._initialPosition = pos
    @boxes[label] = container

  parseItems = (source, target)->
    items = {}
    for item in [source, target]
      items[itemMap[item.dia.constructor.name]] = item
    return items

  type = (item)->
    itemMap[item.dia.constructor.name] or null

  viewAppended:->
    super

    @addSubView @slider = new KDSliderBarView
      cssClass   : 'zoom-slider'
      minValue   : 0.3
      maxValue   : 1.0
      interval   : 0.1
      width      : 120
      snap       : no
      snapOnDrag : no
      drawBar    : yes
      showLabels : no
      handles    : [1]

    handle   = @slider.handles.first

    @addSubView zoomControls = new KDCustomHTMLView
      cssClass   : "zoom-controls"

    zoomControls.addSubView zoomOut = new KDCustomHTMLView
      tagName    : "a"
      cssClass   : "zoom-control zoomout"
      partial    : "-"
      click      : -> handle.setValue handle.value-0.1

    zoomControls.addSubView zoomIn = new KDCustomHTMLView
      tagName    : "a"
      cssClass   : "zoom-control zoomin"
      partial    : "+"
      click      : -> handle.setValue handle.value+0.1

    @slider.on 'ValueIsChanging', (value)=>
      do _.throttle => @setScale value

    @slider.on 'ValueChanged', (handle)=>
      @appStorage.setValue 'zoomLevel', handle.value

    @addSubView resetView = new KDButtonView
      cssClass   : "reset-view"
      title      : "Reset layout"
      icon       : yes
      callback   : @bound 'resetLayout'

    @appStorage.ready =>
      zoomLevel = @appStorage.getValue 'zoomLevel'
      @slider.setValue zoomLevel  if zoomLevel

  resetLayout:->
    box.resetPosition()  for _key, box of @boxes
    @slider.setValue 1

class EnvironmentApprovalModal extends KDModalView

  getContentFor = ({domain, machine}, action)->
    content = 'God knows.'
    if action is 'create'
      content = """Do you want to assign <b>#{domain.dia.data.title}</b>
                   to <b>#{machine.dia.data.title}</b> machine?"""
    else if action is 'delete'
      content = """Do you want to remove <b>#{domain.dia.data.title}</b>
                   domain from <b>#{machine.dia.data.title}</b> machine?"""
    return "<div class='modalformline'><p>#{content}</p></div>"

  constructor:(options={}, data)->

    options.title       or= "Are you sure?"
    options.overlay      ?= yes
    options.overlayClick ?= no
    options.buttons       =
      Yes                 :
        loader            :
          color           : "#444444"
          diameter        : 12
        cssClass          : if options.action is 'delete' \
                            then "modal-clean-red" else "modal-clean-green"
        callback          : =>
          @buttons.Yes.showLoader()
          @emit 'Approved'
      Cancel              :
        cssClass          : "modal-cancel"
        callback          : =>
          @emit 'Cancelled'
          @cancel()

    options.content = getContentFor data, options.action

    super options, data