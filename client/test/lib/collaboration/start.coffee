helpers              = require '../helpers/helpers.js'
ideHelpers           = require '../helpers/idehelpers.js'
utils                = require '../utils/utils.js'
collaborationHelpers = require '../helpers/collaborationhelpers.js'
terminalHelpers      = require '../helpers/terminalhelpers.js'
assert               = require 'assert'


module.exports =

  before: (browser) -> utils.beforeCollaborationSuite browser

  afterEach: (browser, done) -> utils.afterEachCollaborationTest browser, done

  # start: (browser) ->

  #   callback = ->

  #     collaborationHelpers.leaveSession(browser)
  #     collaborationHelpers.waitParticipantLeaveAndEndSession(browser)

  #     browser.end()


  #   browser.pause 2500, -> # wait for user.json creation
  #     collaborationHelpers.initiateCollaborationSession(browser, callback, callback)


  # runCommandOnTerminal: (browser) ->

  #   host           = utils.getUser no, 0
  #   hostBrowser    = process.env.__NIGHTWATCH_ENV_KEY is 'host_1'
  #   terminalText   = host.teamSlug
  #   activeTerminal = '.kdtabpaneview.terminal.active'

  #   hostCallback = ->

  #     browser.element 'css selector', activeTerminal, (result) ->
  #       if result.status is 0
  #         helpers.runCommandOnTerminal(browser, terminalText)
  #       else
  #         terminalHelpers.openNewTerminalMenu(browser)
  #         terminalHelpers.openTerminal(browser)
  #         helpers.runCommandOnTerminal(browser, terminalText)

  #       collaborationHelpers.waitParticipantLeaveAndEndSession(browser)
  #       browser.end()


  #   participantCallback = ->

  #     browser
  #       .waitForElementVisible activeTerminal, 50000
  #       .waitForTextToContain  activeTerminal, terminalText

  #     collaborationHelpers.leaveSession(browser)
  #     browser.end()


  #   collaborationHelpers.initiateCollaborationSession(browser, hostCallback, participantCallback)


  openFile: (browser) ->

    host                   = utils.getUser no, 0
    hostBrowser            = process.env.__NIGHTWATCH_ENV_KEY is 'host_1'
    paneSelector           = '.kdsplitview-panel.panel-1 .pane-wrapper .application-tab-handle-holder'
    lineWidgetSelector     = '.kdtabpaneview.active .ace-line-widget-'
    participantFileName    = 'python.py'
    participantFileContent = 'Hello World from Python by Koding'

    hostCallback = ->

      ideHelpers.openFileFromConfigFolder browser, host
      collaborationHelpers.answerPermissionRequest(browser, yes)
      browser.pause 4000
      browser.waitForElementVisible "#{paneSelector} .pythonpy",  60000
      collaborationHelpers.waitParticipantLeaveAndEndSession(browser)
      browser.end()


    participantCallback = ->
      browser.pause 4000
      browser.waitForElementVisible "#{paneSelector} .indexhtml", 60000
      collaborationHelpers.requestPermission(browser, yes)
      ideHelpers.openFileFromConfigFolder browser, host, participantFileName, participantFileContent
      collaborationHelpers.leaveSession(browser)
      browser.end()


    collaborationHelpers.initiateCollaborationSession(browser, hostCallback, participantCallback, yes)


  # openTerminalWithInvitedUser: (browser) ->

  #   host         = utils.getUser no, 0
  #   hostBrowser  = process.env.__NIGHTWATCH_ENV_KEY is 'host_1'
  #   paneSelector = '.pane-wrapper .kdsplitview-panel.panel-1'
  #   terminalTab  = "#{paneSelector} .application-tab-handle-holder .kdtabhandle.terminal.active"
  #   terminalPane = "#{paneSelector} .kdtabpaneview.terminal.active .terminal-pane"

  #   commonCallback = ->

  #     browser
  #       .waitForElementVisible terminalTab,  35000
  #       .pause                 6000 # wait for connecting text
  #       .assert.containsText   terminalPane, host.username


  #   hostCallback = ->

  #     collaborationHelpers.answerPermissionRequest(browser, yes)
  #     commonCallback()
  #     browser.pause 6000
  #     collaborationHelpers.waitParticipantLeaveAndEndSession(browser)
  #     browser.end()

  #   participantCallback = ->

  #     collaborationHelpers.requestPermission(browser, yes)
  #     terminalHelpers.openNewTerminalMenu(browser)
  #     terminalHelpers.openTerminal(browser)
  #     commonCallback()

  #     collaborationHelpers.leaveSession(browser)
  #     browser.end()


  #   collaborationHelpers.initiateCollaborationSession(browser, hostCallback, participantCallback)
