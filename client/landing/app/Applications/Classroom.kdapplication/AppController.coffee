class ClassroomAppController extends AppController

  KD.registerAppClass this,
    name            : "Classroom"
    route           : "/:name?/Develop/Classroom"
    navItem         :
      title         : "Classroom"

  constructor: (options = {}, data) ->

    options.view    = new ClassroomAppView

    options.appInfo =
      type          : "application"
      name          : "Classroom"

    super options, data
    