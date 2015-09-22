kd                 = require 'kd'
FSFile             = require 'app/util/fs/fsfile'
IDEPane            = require './idepane'
AceView            = require 'ace/aceview'
IDEAce             = require '../../views/ace/ideace'


module.exports = class IDETailerPane extends IDEPane

  constructor: (options = {}, data) ->

    options.cssClass = kd.utils.curry 'editor-pane', options.cssClass
    options.paneType = 'tailer'
    { @file }        = options

    super options, data

    @hash = @file.paneHash  if @file.paneHash

    @createEditor()


  handleFileUpdate: (newLine) ->

    @scrollToBottom()
    @getEditor().insert "\n#{newLine}"


  createEditor: ->

    { file, description, descriptionView } = @getOptions()

    unless file instanceof FSFile
      throw new TypeError 'File must be an instance of FSFile'

    aceOptions =
      delegate                 : @getDelegate()
      createBottomBar          : no
      createFindAndReplaceView : no
      aceClass                 : IDEAce

    @addSubView @aceView = new AceView aceOptions, file

    { ace } = @aceView

    ace.ready =>

      ace.setReadOnly      yes
      ace.setScrollPastEnd no

      { descriptionView, description } = @getOptions()
      file = @getData()

      ace.descriptionView = descriptionView ? new kd.View
        partial : description ? "
          This is a file watcher pane, which allows you to watch all additions
          on <strong>#{@file.getPath()}</strong>. This view is read-only, you
          can't change the content of this file from this view, to be able to
          that please open it in edit-mode.
        "
        click : =>
          ace.descriptionView.destroy()
          @resize()

      ace.descriptionView.setClass 'description-view'
      ace.prepend ace.descriptionView

      @emit 'EditorIsReady'

      kite = @file.machine.getBaseKite()
      kite.tail
        path  : @file.getPath()
        watch : @bound 'handleFileUpdate'

      @resize()


  getAce: ->

    return @aceView.ace


  getEditor: ->

    return @getAce().editor


  setFocus: (state) ->

    super state

    return  unless ace = @getEditor()

    if state
    then ace.focus()
    else ace.blur()

    @parent.tabHandle.unsetClass 'modified'


  getContent: ->

    return if @getEditor() then @getAce().getContents() else ''


  setContent: (content, emitFileContentChangedEvent = yes) ->

    @getAce().setContent content, emitFileContentChangedEvent


  getCursor: ->

    return @getEditor().selection.getCursor()


  setCursor: (positions) ->

    @getEditor().selection.moveCursorTo positions.row, positions.column


  getFile: ->

    return @aceView.getData()


  serialize: ->

    file           = @getFile()
    { paneType }   = @getOptions()
    { name, path } = file

    data       =
      file     : { name, path }
      paneType : paneType
      hash     : @hash

    return data


  scrollToBottom: ->

    content = @getContent()
    line    = (content.split '\n').length

    @setCursor row: line, column: 0


  resize: ->

    height = @getHeight()
    ace    = @getAce()

    ace.setHeight height
    ace.editor.resize()

    @scrollToBottom()
