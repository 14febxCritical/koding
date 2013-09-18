class FSFile extends FSItem

  constructor:->
    super

    @on "file.requests.saveAs", (contents, name, parentPath)=>
      @saveAs contents, name, parentPath

    @on "file.requests.save", (contents)=>
      @save contents

  fetchContentsBinary: (callback)->
    @fetchContents callback, no

  fetchContents:(callback, useEncoding=yes)->

    @emit "fs.job.started"
    @vmController.run
      method    : 'fs.readFile'
      vmName    : @vmName
      withArgs  :
        path    : FSHelper.plainPath @path
    , (err, response)=>

      if err then warn err
      else
        content = atob response.content

        if useEncoding
          content = KD.utils.utf8Decode content # Convert to String

      callback.call @, err, content
      @emit "fs.job.finished", err, content

  saveAs:(contents, name, parentPath, callback)->

    @vmName = FSHelper.getVMNameFromPath parentPath  if parentPath
    newPath = FSHelper.plainPath "#{parentPath}/#{name}"
    @emit "fs.saveAs.started"

    FSHelper.ensureNonexistentPath "#{newPath}", @vmName, (err, path)=>
      if err
        callback? err, path
        warn err
      else
        newFile = FSHelper.createFile
          type   : 'file'
          path   : path
          vmName : @vmName
        newFile.save contents, (err, res)=>
          if err then warn err
          else
            @emit "fs.saveAs.finished", newFile, @

  save:(contents, callback)->

    @emit "fs.save.started"

    # Convert to base64
    content = btoa KD.utils.utf8Encode contents

    @vmController.run
      method    : 'fs.writeFile'
      vmName    : @vmName
      withArgs  :
        path    : FSHelper.plainPath @path
        content : content
    , (err, res)=>

      if err then warn err
      @emit "fs.save.finished", err, res
      callback? err,res
