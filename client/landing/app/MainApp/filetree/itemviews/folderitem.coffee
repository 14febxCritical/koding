class NFolderItemView extends NFileItemView

  constructor:(options = {},data)->

    options.cssClass  or= "folder"
    super options, data

    data.on "fs.chmod.finished", (recursive)=>
      warn "todo : refresh folder" if recursive
