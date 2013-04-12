class GroupGeneralSettingsView extends JView

  constructor:->

    super

    @setClass "general-settings-view group-admin-modal"

    group = @getData()

    unless group?
      group = {}
      isNewGroup = yes
    isPrivateGroup = 'private' is group.privacy

    _updateGroupHandler =(group, formData)=>
      log formData
      formData.avatar = @customUrl if @customUrl
      log formData
      group.modify formData, (err)->
        if err
          new KDNotificationView
            title: err.message
            duration: 1000
        else
          new KDNotificationView
            title: 'Group was updated!'
            duration: 1000

    formOptions =
      title: if isNewGroup then 'Create a group' else 'Edit group'
      callback:(formData)=>
        if isNewGroup
          _createGroupHandler.call @, formData
        else
          _updateGroupHandler group, formData
      buttons:
        Save                :
          style             : "modal-clean-gray"
          type              : "submit"
          loader            :
            color           : "#444444"
            diameter        : 12
        Cancel              :
          style             : "modal-clean-gray"
          loader            :
            color           : "#ffffff"
            diameter        : 16
          callback          : -> modal.destroy()
      fields:
        "Avatar"              :
          label             : "Avatar"
          cssClass        : 'avatar'
          limit           : 1
          preview         : "thumbs"
          extensions      : null
          fileMaxSize     : 2048
          totalMaxSize    : 2048
          fieldName       : "thumbnails"
          convertToBlob   : yes
          title           : ""
          itemClass         : KDImageUploadView
          actions         : {
            big    :
              [
                'scale', {
                  shortest: 400
                }
                'crop', {
                  width   : 400
                  height  : 400
                }
              ]
            medium         :
              [
                'scale', {
                  shortest: 200
                }
                'crop', {
                  width   : 200
                  height  : 200
                }
              ]
            small         :
              [
                'scale', {
                  shortest: 60
                }
                'crop', {
                  width   : 60
                  height  : 60
                }
              ]
          }
        Title               :
          label             : "Group Name"
          itemClass         : KDInputView
          name              : "title"
          keydown           : (pubInst, event)=>
            value = @settingsForm.inputs.Title.getValue()
            setTimeout =>
              slug = @utils.slugify @settingsForm.inputs.Title.getValue()
              @settingsForm.inputs.Slug.setValue slug
            , 1
          defaultValue      : Encoder.htmlDecode group.title ? ""
          placeholder       : 'Please enter a title here'
        Slug :
          itemClass         : KDInputView
          label             : 'Path'
          name              : "slug"
          defaultValue      : group.slug ? ""
          placeholder       : 'This value will be automatically generated'
        Description         :
          label             : "Description"
          type              : "textarea"
          itemClass         : KDInputView
          name              : "body"
          defaultValue      : Encoder.htmlDecode group.body ? ""
          placeholder       : 'Please enter a description here.'
          autogrow          : yes
        "Privacy settings"  :
          itemClass         : KDSelectBox
          label             : "Privacy"
          type              : "select"
          name              : "privacy"
          defaultValue      : group.privacy ? "public"
          selectOptions     : [
            { title : "Public",    value : "public" }
            { title : "Private",   value : "private" }
          ]
        "Visibility settings"  :
          itemClass         : KDSelectBox
          label             : "Visibility"
          type              : "select"
          name              : "visibility"
          defaultValue      : group.visibility ? "visible"
          selectOptions     : [
            { title : "Visible",    value : "visible" }
            { title : "Hidden",     value : "hidden" }
          ]

    @settingsForm = new KDFormViewWithFields formOptions, @getData()

    avatarUploadView = @settingsForm.inputs["Avatar"]
    avatarUploadView.on 'FileReadComplete', ({file, progressEvent})->
      log 'read'
      avatarUploadView.$('.kdfileuploadarea').css
        backgroundImage : "url(#{file.data})"
      avatarUploadView.$('span').addClass 'hidden'

    avatarUploadView.on 'FileUploadComplete', (res)=>
      log 'upload',res
      if res.length and res[0].resource
        @customUrl = res[0].resource

    # avatarUploadView.on 'FileUploadComplete', (files)->
    #   for {filename, resource} in files
    #     console.log {filename, resource}



  viewAppended:->
    super

  pistachio:->
    """
    {{> @settingsForm}}
    """
