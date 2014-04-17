
# Fetch version info from VERSION file
fs          = require 'fs'
nodePath    = require 'path'
versionFile = nodePath.join(__dirname, 'VERSION')
if fs.existsSync versionFile
  version = (fs.readFileSync versionFile, 'utf-8').trim()

KODING_VERSION    = version ? "0.0.1"

projects      =

  KDBackend   :
    path      : "client/Bongo"
    script    : "website/a/js/bongo.#{KODING_VERSION}.js"
    sourceMapRoot : "Bongo/"

  KDMainApp   :
    path      : "client/Main"
    style     : "website/a/css/__kdapp.#{KODING_VERSION}.css"
    script    : "website/a/js/__kdapp.#{KODING_VERSION}.js"
    sourceMapRoot : "Main/"

  Activity        :
    path          : "client/Social/Activity"
    style         : "website/a/css/__app.activity.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.activity.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Activity/"

  Members         :
    path          : "client/Social/Members"
    style         : "website/a/css/__app.members.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.members.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Members/"

  Topics          :
    path          : "client/Social/Topics"
    style         : "website/a/css/__app.topics.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.topics.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Topics/"

  Feeder          :
    path          : "client/Social/Feeder"
    style         : "website/a/css/__app.feeder.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.feeder.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Feeder/"

  # Groups          :
  #   path          : "client/Groups"
  #   style         : "website/a/css/__app.groups.#{KODING_VERSION}.css"
  #   script        : "website/a/js/__app.groups.#{KODING_VERSION}.js"
  #   sourceMapRoot : "Groups/"

  Account         :
    path          : "client/Account"
    style         : "website/a/css/__app.account.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.account.#{KODING_VERSION}.js"
    sourceMapRoot : "Account/"

  Login           :
    path          : "client/Login"
    style         : "website/a/css/__app.Login.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.Login.#{KODING_VERSION}.js"
    sourceMapRoot : "Login/"

  Apps            :
    path          : "client/Social/Apps"
    style         : "website/a/css/__app.apps.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.apps.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Apps/"

  Terminal        :
    path          : "client/Terminal"
    style         : "website/a/css/__app.terminal.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.terminal.#{KODING_VERSION}.js"
    sourceMapRoot : "Terminal/"

  Ace             :
    path          : "client/Ace"
    style         : "website/a/css/__app.ace.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.ace.#{KODING_VERSION}.js"
    sourceMapRoot : "Ace/"

  Finder          :
    path          : "client/Finder"
    style         : "website/a/css/__app.finder.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.finder.#{KODING_VERSION}.js"
    sourceMapRoot : "Finder/"

  Viewer          :
    path          : "client/Viewer"
    style         : "website/a/css/__app.viewer.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.viewer.#{KODING_VERSION}.js"
    sourceMapRoot : "Viewer/"

  Workspace       :
    path          : "client/Workspace"
    style         : "website/a/css/__app.workspace.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.workspace.#{KODING_VERSION}.js"
    sourceMapRoot : "Workspace/"

  CollaborativeWorkspace:
    path          : "client/CollaborativeWorkspace"
    style         : "website/a/css/__app.collaborativeworkspace.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.collaborativeworkspace.#{KODING_VERSION}.js"
    sourceMapRoot : "CollaborativeWorkspace/"

  Teamwork        :
    path          : "client/Teamwork"
    style         : "website/a/css/__app.teamwork.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.teamwork.#{KODING_VERSION}.js"
    sourceMapRoot : "Teamwork/"

  About           :
    path          : "client/About"
    style         : "website/a/css/__app.about.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.about.#{KODING_VERSION}.js"
    sourceMapRoot : "About/"

  Home            :
    path          : "client/Home"
    style         : "website/a/css/__app.home.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.home.#{KODING_VERSION}.js"
    sourceMapRoot : "Home/"

  Business        :
    path          : "client/Business"
    style         : "website/a/css/__app.business.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.business.#{KODING_VERSION}.js"
    sourceMapRoot : "Business/"

  Education       :
    path          : "client/Education"
    style         : "website/a/css/__app.education.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.education.#{KODING_VERSION}.js"
    sourceMapRoot : "Education/"

  Environments    :
    path          : "client/Environments"
    style         : "website/a/css/__app.environments.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.environments.#{KODING_VERSION}.js"
    sourceMapRoot : "Environments/"

  PostOperations  :
    path          : "client/PostOperations"
    script        : "website/a/js/__client.post.#{KODING_VERSION}.js"

  Dashboard       :
    path          : "client/Dashboard"
    style         : "website/a/css/__app.dashboard.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.dashboard.#{KODING_VERSION}.js"
    sourceMapRoot : "Dashboard/"

  Pricing         :
    path          : "client/Pricing"
    style         : "website/a/css/__app.pricing.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.pricing.#{KODING_VERSION}.js"
    sourceMapRoot : "Pricing/"

  Demos           :
    path          : "client/Demos"
    style         : "website/a/css/__app.demos.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.demos.#{KODING_VERSION}.js"
    sourceMapRoot : "Demos/"

  Bugs            :
    path          : "client/Social/Bugs"
    style         : "website/a/css/__app.bugreport.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.bugreport.#{KODING_VERSION}.js"
    sourceMapRoot : "Social/Bugs/"

  DevTools        :
    path          : "client/DevTools"
    style         : "website/a/css/__app.devtools.#{KODING_VERSION}.css"
    script        : "website/a/js/__app.devtools.#{KODING_VERSION}.js"
    sourceMapRoot : "DevTools/"

bundles           =

  Social          :
    projects      : ['Activity', 'Members', 'Topics', 'Apps', 'Bugs']
    style         : "website/a/css/__social.#{KODING_VERSION}.css"
    script        : "website/a/js/__social.#{KODING_VERSION}.js"

  Koding          :
    projects      : ['KDBackend', 'KDMainApp', 'Finder', 'Login', 'PostOperations']
    style         : "website/a/css/koding.#{KODING_VERSION}.css"
    script        : "website/a/js/koding.#{KODING_VERSION}.js"

  TeamworkBundle  :
    projects      : ['Ace', 'Terminal', 'Viewer', 'Workspace',
                     'CollaborativeWorkspace', 'Teamwork', 'DevTools']
    style         : "website/a/css/__teamwork.#{KODING_VERSION}.css"
    script        : "website/a/js/__teamwork.#{KODING_VERSION}.js"

  Payment         :
    projects      : ['Environments', 'Dashboard', 'Pricing', 'Account']
    style         : "website/a/css/__payment.#{KODING_VERSION}.css"
    script        : "website/a/js/__payment.#{KODING_VERSION}.js"

module.exports  = {projects, bundles}
