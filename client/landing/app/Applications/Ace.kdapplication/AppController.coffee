class AceAppController extends AppController

  KD.registerAppClass @,
    name          : "Ace"
    multiple      : yes
    hiddenHandle  : no
    openWith      : "lastActive"
    route         : "/Develop"
    behavior      : "application"
    menu          : [
      {
        title     : "Save"
        eventName : "save"
      }
      {
        title     : "Save As"
        eventName : "saveAs"
      }
      {
        type      : "separator"
      }
      {
        title     : "Compile and Run"
        eventName : "compileAndRun"
      }
      {
        type      : "separator"
      }
      {
        title     : "Preview"
        eventName : "preview"
      }
      {
        type      : "separator"
      }
      {
        title     : "Recently Opened"
        eventName : "recents"
        closeMenuWhenClicked: no
      }
      {
        title     : "Reopen lastest files"
        eventName : "reopen"
      }
    ]
    # mimeTypes    : "text"

  constructor: (options = {}, data)->

    options.view = new AceAppView
    options.appInfo =
      name         : "Ace"
      type         : "application"
      cssClass     : "ace"

    super options, data

    @on "AppDidQuit", -> @getView().emit "AceAppDidQuit"


  openFile: (file) ->

   @getView().openFile file
