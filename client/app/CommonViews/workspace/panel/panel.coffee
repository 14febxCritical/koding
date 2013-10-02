class Panel extends JView

  constructor: (options = {}, data) ->

    options.cssClass = "panel"

    super options, data

    @headerButtons  = {}
    @panesContainer = []
    @panes          = []
    @panesByName    = {}
    @header         = new KDCustomHTMLView

    {title}         = options
    buttonsLength   = options.buttons?.length

    @createHeader title     if title or buttonsLength
    @createHeaderButtons()  if buttonsLength
    @createHeaderHint()     if options.hint

    @createLayout()

  createHeader: (title = "") ->
    @header        = new KDView cssClass : "inner-header"
    @headerTitle   = new KDCustomHTMLView
      tagName      : "span"
      cssClass     : "title"
      partial      : title

    @header.addSubView @headerTitle

    {headerStyling} = @getOptions()
    @applyHeaderStyling headerStyling if headerStyling

  createHeaderButtons: ->
    # TODO: fatihacet - DRY
    @getOptions().buttons.forEach (buttonOptions) =>
      if buttonOptions.itemClass
        Klass = buttonOptions.itemClass
        delete buttonOptions.itemClass
        buttonOptions.callback = buttonOptions.callback?.bind this, this, @getDelegate()

        buttonView = new Klass buttonOptions
      else
        buttonOptions.callback = buttonOptions.callback?.bind this, this, @getDelegate()
        buttonView = new KDButtonView buttonOptions

      @headerButtons[buttonOptions.title] = buttonView
      @header.addSubView buttonView

  createHeaderHint: ->
    @header.addSubView new KDCustomHTMLView
      cssClass  : "help"
      tooltip   :
        title   : "Need help?"
      click     : => @showHintModal()

  createLayout: ->
    {pane, layout} = @getOptions()
    @container     = new KDView
      cssClass     : "panel-container"

    if pane
      newPane = @createPane pane
      @container.addSubView newPane
      @getDelegate().emit "AllPanesAddedToPanel", this, [newPane]
    else if layout
      @layoutContainer = new WorkspaceLayout
        delegate       : this
        layoutOptions  : layout

      @container.addSubView @layoutContainer
    else
      warn "no layout config or pane passed to create a panel"

  createPane: (paneOptions) ->
    PaneClass = @getPaneClass paneOptions
    pane      = new PaneClass paneOptions

    @panesByName[paneOptions.name] = pane  if paneOptions.name

    @panes.push pane
    @emit "NewPaneCreated", pane
    return pane

  getPaneClass: (paneOptions) ->
    paneType             = paneOptions.type
    paneOptions.delegate = this

    PaneClass = if paneType is "custom" then paneOptions.paneClass else @findPaneClass paneType

    return unless PaneClass
      new Error "PaneClass is not defined for \"#{paneOptions.type}\" pane type"

    return PaneClass

  findPaneClass: (paneType) ->
    paneTypesToPaneClass =
      "terminal"         : @TerminalPaneClass
      "editor"           : @EditorPaneClass
      "video"            : @VideoPaneClass
      "preview"          : @PreviewPaneClass
      "finder"           : @FinderPaneClass
      "tabbedEditor"     : @TabbedEditorPaneClass
      "drawing"          : @DrawingPaneClass

    return paneTypesToPaneClass[paneType]

  getPaneByName: (name) ->
    return @panesByName[name] or null

  showHintModal: ->
    options        = @getOptions()
    modal          = new KDModalView
      cssClass     : "workspace-modal"
      overlay      : yes
      title        : options.title
      content      : options.hint
      buttons      :
        Close      :
          title    : "Close"
          cssClass : "modal-cancel"
          callback : -> modal.destroy()

  applyHeaderStyling: (options) ->
    {bgColor, bgGradient, bgImage, textColor, textShadowColor, borderColor} = options

    @header.setCss      "color"             , textColor                        if textColor
    @header.setCss      "textShadowColor"   , "1px 1px 1px #{textShadowColor}" if textShadowColor
    @header.setCss      "borderBottomColor" , "#{borderColor}"                 if borderColor
    @header.setCss      "background"        , "#{bgColor}"                     if bgColor
    @headerTitle.setCss "backgroundImage"   , "url(#{bgImage})"                if bgImage

    if bgGradient
      KD.utils.applyGradient @header, bgGradient.first, bgGradient.last

  viewAppended: ->
    super
    @getDelegate().emit "NewPanelAdded", this

  pistachio: ->
    """
      {{> @header}}
      {{> @container}}
    """

  EditorPaneClass       : EditorPane
  TabbedEditorPaneClass : EditorPane
  TerminalPaneClass     : TerminalPane
  VideoPaneClass        : VideoPane
  PreviewPaneClass      : PreviewPane
  DrawingPaneClass      : KDView
