class ClassroomChapterList extends KDScrollView

  constructor: (options = {}, data) ->

    options.cssClass or= "classroom-chapters"

    super options, data

    courseName = @getData().name
    appStorage = KD.getSingleton("appStorageController").storage "Classroom"
    completed  = appStorage.getValue("CompletedChapters")?[courseName]

    for chapter, index in @getData().chapters
      chapter.index      = index
      chapter.courseName = courseName
      chapter.completed  = completed.indexOf(chapter.title) > -1

      @addSubView new ClassroomChapterThumbView
        delegate   : this
        courseRoot : "#{ClassroomAppView::cdnRoot}/#{@getData().name}.kdcourse"
      , chapter
