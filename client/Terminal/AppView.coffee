class WebTermAppView extends JView

  constructor: (options = {}, data) ->

    super options, data

    @tabHandleContainer = new ApplicationTabHandleHolder
      delegate          : this
      addPlusHandle     : yes

    @tabView = new ApplicationTabView
      delegate                  : this
      tabHandleContainer        : @tabHandleContainer
      resizeTabHandles          : yes
      closeAppWhenAllTabsClosed : no

    @tabView.on 'PaneDidShow', (pane) =>
      @_windowDidResize()
      {terminalView} = pane.getOptions()
      terminalView.on 'viewAppended', -> terminalView.terminal.setFocused yes
      terminalView.once 'viewAppended', => @emit "ready"
      terminalView.terminal?.setFocused yes
      terminalView.terminal?.scrollToBottom()
      KD.utils.defer -> terminalView.setKeyView()

      terminalView.on "WebTerm.terminated", (server) =>
        if not pane.isDestroyed and @tabView.getActivePane() is pane
          @tabView.removePane pane

    @on "KDObjectWillBeDestroyed", ->
      KD.getSingleton("mainView").disableFullscreen()

    @messagePane = new KDCustomHTMLView
      cssClass   : 'message-pane'
      partial    : 'Loading Terminal...'

    @tabView.on 'AllTabsClosed', =>
      @setMessage "All tabs are closed. <a class='plus' href='#'>Click to open a new Terminal</a>.", no, yes

    @tabView
      .on('PaneRemoved', @bound 'updateSessions')
      .on('TabsSorted', @bound 'updateSessions')

  setMessage:(msg, light = no, bindClick = no)->
    @messagePane.updatePartial msg
    if light
    then @messagePane.setClass   'light'
    else @messagePane.unsetClass 'light'
    @messagePane.show()

    if bindClick
      @messagePane.once 'click', (event)=>
        KD.utils.stopDOMEvent event
        if $(event.target).hasClass 'close'
          KD.singleton('router').back()
          KD.singleton('appManager').quitByName 'Terminal'
        else if $(event.target).hasClass 'plus'
          @addNewTab()

  restoreTabs: (vmName) ->
    storage = KD.getSingleton('appStorageController').storage 'Terminal', '1.0.1'
    storage.fetchStorage =>
      sessions = storage.getValue 'savedSessions'
      if sessions?.length
        for session in sessions
          [vmName, sessionId] = session.split ':'
          @createNewTab { vmName, session: sessionId }
      else
        @addNewTab vmName

  checkVM:->

    vmController = KD.getSingleton 'vmController'
    vmController.fetchDefaultVmName (vmName)=>

      KD.mixpanel "Open Webterm, click", {vmName}

      unless vmName
        return @setMessage "It seems you don't have a VM to use with Terminal."

      vmController.info vmName, KD.utils.getTimedOutCallback (err, vm, info)=>
        if err
          KD.logToExternal "oskite: Error opening Webterm", vmName, err
          KD.mixpanel "Open Webterm, fail", {vmName}

        if info?.state is 'RUNNING'
          @restoreTabs vmName
        else
          vmController.start vmName, (err, state)=>
            warn "Failed to turn on vm:", err  if err
            KD.utils.defer => @addNewTab vmName
        KD.mixpanel "Open Webterm, success", {vmName}

      , =>
        KD.mixpanel "Open Webterm, fail", {vmName}
        KD.logToExternalWithTime "oskite: Can't open Webterm", vmName
        @setMessage "Couldn't connect to your VM, please try again later. <a class='close' href='#'>close this</a>", no, yes
      , 10000

  showApprovalModal: (remote, command)->
    modal = new KDModalView
      title   : "Warning!"
      content : """
      <div class="modalformline">
        <p>
          If you <strong>don't trust this app</strong>, or if you clicked on this
          link <strong>not knowing what it would do</strong> - be careful it <strong>can
          damage/destroy</strong> your Koding VM.
        </p>
      </div>
      <div class="modalformline">
        <p>
          This URL is set to execute the command below:
        </p>
      </div>
      <pre>
        #{Encoder.XSSEncode command}
      </pre>
      """
      buttons :
        "Run" :
          cssClass: "modal-clean-gray"
          callback: ->
            remote.input "#{command}\n"
            modal.destroy()
        "Cancel":
          cssClass: "modal-cancel"
          callback: ->
            modal.destroy()

  getAdvancedSettingsMenuView: (item, menu)->
    pane = @tabView.getActivePane()
    return  unless pane

    {terminalView} = pane.getOptions()
    settingsView = new KDView
      cssClass: "editor-advanced-settings-menu"
    settingsView.addSubView new WebtermSettingsView
      menu    : menu
      delegate: terminalView

    return settingsView

  runCommand:(_command)->
    pane = @tabView.getActivePane()
    {terminalView} = pane.getOptions()

    runner = =>
      terminalView.terminal.scrollToBottom()
      command = decodeURIComponent _command

      # FIXME Make it more elegant later.
      safeCommands = ['help this', 'help sudo', 'help ftp', 'help mysql',
                      'help programs', 'help phpmyadmin', 'help mongodb',
                      'help specs', 'help']

      if _command in safeCommands
        terminalView.terminal.server.input "#{command}\n"
      else
        @showApprovalModal terminalView.terminal, command

    if terminalView.terminal?.server?
    then runner()
    else terminalView.once 'WebTermConnected', runner

  handleQuery:(query)->
    pane = @tabView.getActivePane()
    {terminalView} = pane.getOptions()
    terminalView.terminal?.scrollToBottom()
    terminalView.once 'WebTermConnected', (remote)=>

      if query.command
        command = decodeURIComponent query.command
        @showApprovalModal remote, command

      # chrome app specific settings
      if query.chromeapp

        query.fullscreen = yes # forcing fullscreen
        @chromeAppMode()

      if query.fullscreen
        KD.getSingleton("mainView").enableFullscreen()

  chromeAppMode: ->
    windowController = KD.getSingleton("windowController")
    mainController   = KD.getSingleton("mainController")

    # talking with chrome app
    if window.parent?.postMessage
      {parent} = window
      mainController.on "clientIdChanged", ->
        parent.postMessage "clientIdChanged", "*"

      parent.postMessage "fullScreenTerminalReady", "*"
      parent.postMessage "loggedIn", "*"  if KD.isLoggedIn()

      @on "KDObjectWillBeDestroyed", ->
        parent.postMessage "fullScreenWillBeDestroyed", "*"

    @addSubView new ChromeTerminalBanner

  viewAppended: ->
    super
    @checkVM()

  createNewTab: (options = {}) ->

    terminalView   = new WebTermView
      testPath    : "webterm-tab"
      delegate    : this
      vmName      : options.vmName
      session     : options.session

    @appendTerminalTab terminalView

  appendTerminalTab: (terminalView) ->

    @forwardEvents terminalView, ['KeyViewIsSet', 'command']

    pane = new KDTabPaneView
      name          : 'Terminal'
      terminalView  : terminalView

    @tabView.addPane pane
    pane.addSubView terminalView

    terminalView.on "WebTermNeedsToBeRecovered", (options) =>
      options.delegate = this
      pane.destroySubViews()
      pane.addSubView new WebTermView options

    terminalView.on 'WebTermConnected', @bound 'updateSessions'

    # terminalView.once 'KDObjectWillBeDestroyed', => @tabView.removePane pane

  updateSessions: ->
    storage = (KD.getSingleton 'appStorageController').storage 'Terminal', '1.0.1'
    storage.fetchStorage =>
      sessions = @tabView.panes.map (pane) =>
        { terminalView } = pane.getOptions()
        sessionId = terminalView.sessionId ? terminalView.getOption 'session'
        "#{ terminalView.getOption 'vmName' }:#{ sessionId }"
      storage.setValue 'savedSessions', sessions

  addNewTab: (vmName)->

    @messagePane.hide()

    if @_secondTab
      KD.mixpanel "Open new Webterm tab, success"

    @_secondTab   = yes

    unless vmName
      @utils.defer =>

        vmc = KD.getSingleton 'vmController'
        if vmc.vms.length > 1
          vmselection = new VMSelection
          vmselection.once 'VMSelected', (vm)=> @createNewTab vmName: vm
        else
          @createNewTab vmName: vmc.vms.first

    else
      @createNewTab vmName: vmName


  pistachio: ->
    """
    {{> @tabHandleContainer}}
    {{> @messagePane}}
    {{> @tabView}}
    """

class ChromeTerminalBanner extends JView
  constructor: (options={}, data)->

    options.domId = "chrome-terminal-banner"

    super options, data

    @descriptionHidden = yes

    @mainView = KD.getSingleton "mainView"
    @router   = KD.getSingleton "router"
    @finder   = KD.getSingleton "finderController"

    @mainView.on "fullscreen", (state)=>
      unless state then @hide() else @show()

    @register   = new CustomLinkView
      cssClass: "action"
      title   : "Register"
      click   : => @revealKoding "/Register"

    @login      = new CustomLinkView
      cssClass: "action"
      title   : "Login"
      click   : => @revealKoding "/Login"

    @whatIsThis = new CustomLinkView
      cssClass : "action"
      title    : "What is This?"
      click    : =>
        if @descriptionHidden
          @description.show()
        else
          @description.hide()
        @descriptionHidden = not @descriptionHidden

    @description = new KDCustomHTMLView
      tagName : "p"
      cssClass: "hidden"
      partial : """
      This is a complete virtual environment provided by Koding. <br>
      Koding is a social development environment. <br>
      Visit and see it in action at <a href="http://koding.com" target="_blank">http://koding.com</a>
      """

    @revealer = new CustomLinkView
      cssClass : "action"
      title    : "Reveal Koding"
      click    : => @revealKoding()

  revealKoding: (route)->
    @finder.mountVm "vm-0.#{KD.nick()}.guests.kd.io" unless KD.isLoggedIn()
    @router.handleRoute route if route
    @mainView.disableFullscreen()

  pistachio: ->
    if KD.isLoggedIn()
      """
      <span class="koding-icon"></span>
      <div class="actions">
        {{> @revealer}}
      </div>
      """
    else
      """
      <span class="koding-icon"></span>
      <div class="actions">
        {{> @register}}
        {{> @login}}
        {{> @whatIsThis}}
      </div>
      {{> @description}}
      """
