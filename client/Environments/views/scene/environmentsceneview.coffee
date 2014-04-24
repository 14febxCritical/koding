class EnvironmentScene extends KDDiaScene

  @containerMap =
    EnvironmentRuleContainer    : 'rules'
    EnvironmentExtraContainer   : 'extras'
    EnvironmentDomainContainer  : 'domains'
    EnvironmentMachineContainer : 'vms'

  itemMap      =
    EnvironmentRuleItem         : 'rule'
    EnvironmentExtraItem        : 'extra'
    EnvironmentDomainItem       : 'domain'
    EnvironmentMachineItem      : 'vm'

  constructor: (stack)->
    super
      cssClass  : 'environments-scene'
      lineWidth : 2
      lineColor : "#4ED393"

    @boxes = {}
    @stack = stack

    sc = KD.getSingleton 'appStorageController'
    @appStorage = sc.storage 'EnvironmentsScene', '1.0.1'

  disconnect:(dia, joint)->

    removeConnection = => KDDiaScene::disconnect.call this, dia, joint
    targetConnection = @findTargetConnection dia, joint
    return unless targetConnection
    {source, target} = targetConnection

    items = parseItems source, target
    return  if Object.keys(items).length < 2
    {domain, vm, rule, extra} = items

    if domain and vm
      jDomain = domain.dia.getData().domain # JDomain
      vmName  = vm.dia.getData().title # JVM.hostnameAlias
      jDomain.unbindVM hostnameAlias: vmName, (err)=>
        return KD.showError err  if err
        jDomain.hostnameAlias.splice jDomain.hostnameAlias.indexOf(vmName), 1
        removeConnection()
    else if domain and rule
      removeConnection()
    else if vm and extra
      removeConnection()

  connect:(source, target, internal = no)->

    createConnection = => KDDiaScene::connect.call this, source, target, !internal

    return createConnection()  if internal

    if not @allowedToConnect source, target
      return new KDNotificationView
        title : "It's not allowed connect this two joint."

    items = parseItems source, target
    return  if Object.keys(items).length < 2
    {domain, vm, rule, extra} = items

    return  if extra
      new KDNotificationView
        title : "Assigning resources will be available soon."

    if domain and vm and not KD.checkFlag 'nostradamus'
      if domain.dia.getData().domain.hostnameAlias.length > 0
        return new KDNotificationView
          title : "A domain name can only be bound to one VM."

    if domain and vm
      jDomain = domain.dia.getData().domain # JDomain
      vmName  = vm.dia.getData().title # JVM.hostnameAlias
      jDomain.bindVM hostnameAlias: vmName, (err)=>
        return  if KD.showError err
        jDomain.hostnameAlias.push vmName
        createConnection()
    else if domain and rule
      createConnection()
      @bindRuleToDomain domain, rule
    else if vm and extra
      createConnection()

  bindRuleToDomain: (domain, rule) ->
    {domain} = domain.dia.getData()
    rule     = rule.dia.getData()

    KD.remote.api.JProxyRestriction.create {
      domainName : domain.domain
      filterId   : rule.getId()
    }, (err, restriction) ->
      if err
        return new KDNotificationView
          type     : "mini"
          cssClass : "error"
          title    : "Sorry, we couldn't bind your rule to your VM, please try again."
          duration : 4000

  updateConnections:->
    @reset no

    vmDias     = @boxes.vms.dias
    domainDias = @boxes.domains.dias

    for _mkey, vm of vmDias
      for _dkey, domain of domainDias
        domainAliases = domain.getData().aliases
        if domainAliases and vm.getData().title in domainAliases
          @connect {dia : domain , joint : 'right'}, \
                   {dia : vm, joint : 'left' }, yes

  createApproveModal:(items, action)->
    return unless KD.isLoggedIn()
      new KDNotificationView
        title : "You need to login to change domain settings."
    return new EnvironmentApprovalModal {action}, items

  addContainer:(container, pos)->
    pos ?= x: 10 + @containers.length * 230, y: 0
    super container, pos

    {name} = container.constructor
    label  = EnvironmentScene.containerMap[name] or name
    container._initialPosition = pos
    @boxes[label] = container

  parseItems = (source, target)->
    items = {}
    for item in [source, target]
      items[itemMap[item.dia.constructor.name]] = item
    return items

  type = (item)->
    itemMap[item.dia.constructor.name] or null

  # viewAppended:->
  #   super

    # @addSubView @slider = new KDSliderBarView
    #   cssClass   : 'zoom-slider'
    #   minValue   : 0.3
    #   maxValue   : 1.0
    #   interval   : 0.1
    #   width      : 120
    #   snap       : no
    #   snapOnDrag : no
    #   drawBar    : yes
    #   showLabels : no
    #   handles    : [1]

    # handle   = @slider.handles.first

    # @addSubView zoomControls = new KDCustomHTMLView
    #   cssClass   : "zoom-controls"

    # zoomControls.addSubView zoomOut = new KDCustomHTMLView
    #   tagName    : "a"
    #   cssClass   : "zoom-control zoomout"
    #   partial    : "-"
    #   click      : -> handle.setValue handle.value-0.1

    # zoomControls.addSubView zoomIn = new KDCustomHTMLView
    #   tagName    : "a"
    #   cssClass   : "zoom-control zoomin"
    #   partial    : "+"
    #   click      : -> handle.setValue handle.value+0.1

    # @slider.on 'ValueIsChanging', (value)=>
    #   do _.throttle => @setScale value

    # @slider.on 'ValueChanged', (handle)=>
    #   @appStorage.setValue 'zoomLevel', handle.value

    # @addSubView resetView = new KDButtonView
    #   cssClass   : "reset-view"
    #   title      : "Reset layout"
    #   icon       : yes
    #   callback   : @bound 'resetLayout'

    # @appStorage.ready =>
    #   zoomLevel = @appStorage.getValue 'zoomLevel'
    #   @slider.setValue zoomLevel  if zoomLevel

  # resetLayout:->
  #   box.resetPosition()  for _key, box of @boxes
  #   @slider.setValue 1

class EnvironmentApprovalModal extends KDModalView

  getContentFor = (items, action)->
    content     = 'God knows.'

    titles = {}
    for title in ['domain', 'vm', 'rule', 'extra']
      titles[title] = items[title].dia.getData().title  if items[title]

    if action is 'create'

      if titles.domain? and titles.vm?
        content = """Do you want to assign <b>#{titles.domain}</b>
                     to <b>#{titles.vm}</b> vm?"""
      else if titles.domain? and titles.rule?
        content = """Do you want to enable <b>#{titles.rule}</b> rule
                     for <b>#{titles.domain}</b> domain?"""
      else if titles.vm? and titles.extra?
        content = """Do you want to add <b>#{titles.extra}</b>
                     to <b>#{titles.vm}</b> vm?"""

    else if action is 'delete'

      if titles.domain? and titles.vm?
        content = """Do you want to remove <b>#{titles.domain}</b>
                     domain from <b>#{titles.vm}</b> vm?"""
      else if titles.domain? and titles.rule?
        content = """Do you want to disable <b>#{titles.rule}</b> rule
                     for <b>#{titles.domain}</b> domain?"""
      else if titles.vm? and titles.extra?
        content = """Do you want to remove <b>#{titles.extra}</b>
                     from <b>#{titles.vm}</b> vm?"""

    return "<div class='modalformline'><p>#{content}</p></div>"

  constructor:(options={}, data)->

    options.title       or= "Are you sure?"
    options.overlay      ?= yes
    options.overlayClick ?= no
    options.buttons       =
      Yes                 :
        loader            :
          color           : "#444444"
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
