kd                 = require 'kd'
FSHelper           = require 'app/util/fs/fshelper'
applyMarkdown      = require 'app/util/applyMarkdown'
IDEEditorPane      = require 'ide/workspace/panes/ideeditorpane'
Encoder            = require 'htmlencode'

remote             = require('app/remote').getInstance()

StacksCustomViews  = require './stacks/stackscustomviews'


module.exports     = class GroupStackSettings extends kd.View

  StacksCustomViews.mixin @prototype

  # This will be used if stack template is not defined yet
  defaultTemplate = """
  {
    "provider": {
      "aws": {
        "access_key": "${var.access_key}",
        "secret_key": "${var.secret_key}",
        "region": "ap-northeast-1"
      }
    },
    "resource": {
      "aws_instance": {
        "example": {
          "instance_type": "t2.micro",
          "ami": "ami-936d9d93"
        }
      }
    }
  }
  """

  constructor: (options = {}, data) ->

    options.cssClass = 'stacks'
    super options, data

    @_credentials = {}


  viewAppended: ->

    @initiateInitialView()


  initiateInitialView: ->

    @replaceViewsWith loader: 'main-loader'

    @fetchData (err, data) =>

      { credentials, stackTemplate } = data

      if err? or not stackTemplate
        @replaceViewsWith noStackFoundView: @bound 'initiateNewStackWizard'
      else
        @replaceViewsWith stacksView: data


  initiateNewStackWizard: ->

    NEW_STACK_STEPS = [
      'stepSelectProvider'
      'stepSetupCredentials'
      'stepBootstrap'
      'stepDefineStack'
      'stepTestAndSave'
    ]

    steps = []

    NEW_STACK_STEPS.forEach (step, index) =>
      steps.push (data) =>
        @replaceViewsWith "#{step}": {
          callback: steps[index+1] or -> console.log 'LAST ONE'
          cancelCallback: steps[index-1] or @bound 'initiateInitialView'
          data
        }

    steps.first()


  createEditorPane: (content) ->

    content = Encoder.htmlDecode content
    file    = FSHelper.createFileInstance path: 'localfile:/stack.json'

    @addSubView editorContainer = new kd.View
    editorContainer.setCss height: '240px'

    editorContainer.addSubView @editorPane = new IDEEditorPane {
      file, content, delegate: this
    }

    @editorPane.setCss background: 'black'


  createCredentialsBox: ->

    creds = ({title: c.title, value: c.publicKey} for c in @_credentials)

    @addSubView new kd.LabelView
      title: "Select credential to use:"

    @addSubView @credentialBox = new kd.SelectBox
      name          : "credential"
      selectOptions : creds


  createOutputView: ->

    @outputView = new kd.View
    @outputView.setCss height: 'auto'

    @addSubView @outputView


  checkCredential: (callback) ->

    selected   = @credentialBox.getValue()
    credential = cred for cred in @_credentials when cred.publicKey is selected

    credential.isBootstrapped (err, state) ->
      return callback err  if err

      callback if not state then {
        message: 'Credential is not bootstrapped yet.'
      } else null


  fetchData: (callback) ->

    { groupsController }            = kd.singletons
    { JCredential, JStackTemplate } = remote.api

    JCredential.some {}, { limit: 30 }, (err, credentials) ->

      return callback {message: 'Failed to fetch credentials:', err}  if err

      currentGroup = groupsController.getCurrentGroup()

      if not currentGroup.stackTemplates?.length > 0
        callback null, {credentials}
        return

      {stackTemplates} = currentGroup
      stackTemplateId  = stackTemplates.first # TODO support multiple templates

      JStackTemplate.some
        _id   : stackTemplateId
      , limit : 1
      , (err, stackTemplates) ->

          if err
            console.warn 'Failed to fetch stack template:', err
            callback null, {credentials}
          else
            stackTemplate = stackTemplates.first
            callback null, {credentials, stackTemplate}


  setStack: (stackTemplate) ->

    terraformContext = @editorPane.getValue()
    publicKeys = [@credentialBox.getValue()]

    console.log {terraformContext, publicKeys}

    { computeController } = kd.singletons

    computeController.getKloud()

      .checkTemplate {terraformContext, publicKeys}

      .then (response) =>

        machines = @parseTerraformOutput response
        @outputView.updatePartial applyMarkdown "
          ```json\n#{JSON.stringify machines, null, 2}\n```
        "

        @updateStackTemplate {
          template: terraformContext
          stackTemplate, publicKeys, machines
        }

      .catch   @bound 'showError'
      .finally @saveButton.bound 'hideLoader'


  showError: (err) ->

    console.warn "ERROR:", err

    err = err.message  if err.message?

    @outputView.updatePartial applyMarkdown """
      An error occured:

      ```json\n#{err}\n```
    """


  updateStackTemplate: (data)->

    { template, publicKeys, machines, stackTemplate } = data

    { JCredential, JStackTemplate } = remote.api

    credentials = publicKeys

    if stackTemplate
      stackTemplate.update {machines, template, credentials}, (err) =>
        return @showError err  if err
        @setGroupTemplate stackTemplate
    else
      JStackTemplate.create {
        title : "Default stack template"
        template, machines, credentials
      }, (err, stackTemplate) =>
        return @showError err  if err
        @setGroupTemplate stackTemplate


  setGroupTemplate: (stackTemplate) ->

    { groupsController } = kd.singletons

    currentGroup = groupsController.getCurrentGroup()
    { slug }     = currentGroup

    if slug is 'koding'
      return new kd.NotificationView
        title: 'Setting stack template for koding is disabled'

    currentGroup.modify stackTemplates: [ stackTemplate._id ], (err) =>
      return @showError err  if err

      new kd.NotificationView
        title: "Group (#{slug}) stack has been saved!"



  parseTerraformOutput: (response) ->

    # An example of a valid stack template
    # ------------------------------------
    # title: "Default stack",
    # description: "Koding's default stack template for new users",
    # machines: [
    #   {
    #     "label" : "koding-vm-0",
    #     "provider" : "koding",
    #     "instanceType" : "t2.micro",
    #     "provisioners" : [
    #         "devrim/koding-base"
    #     ],
    #     "region" : "us-east-1",
    #     "source_ami" : "ami-a6926dce"
    #   }
    # ],

    out = machines: []

    {machines} = response

    for machine, index in machines

      {label, provider, region} = machine
      {instance_type, ami} = machine.attributes

      out.machines.push {
        label, provider, region
        source_ami   : ami
        instanceType : instance_type
        provisioners : [] # TODO what are we going to do with provisioners? ~ GG
      }

    console.info "Kloud's response:", response
    console.info "Converted stack :", out.machines

    return out.machines
