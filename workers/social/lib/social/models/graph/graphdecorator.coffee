module.exports = class GraphDecorator
  ResponseDecorator        = require './decorators/response'
  SingleActivityDecorator  = require './decorators/singleactivity'
  FollowsBucketDecorator   = require './decorators/followbucket'
  InstallsBucketDecorator  = require './decorators/installsbucket'
  NewMemberBucketDecorator = require './decorators/newmemberbucket'

  singleActivityDecorators =
    'JTutorial'     : SingleActivityDecorator
    'JCodeSnip'     : SingleActivityDecorator
    'JDiscussion'   : SingleActivityDecorator
    'JBlogPost'     : SingleActivityDecorator
    'JNewStatusUpdate' : SingleActivityDecorator

  @decorateSingles:(data, callback)->
    cacheObjects    = {}
    overviewObjects = []

    for datum in data
      if klass = singleActivityDecorators[datum.data.name]
        {activity, overview} = (new klass(datum)).decorate()
      else
        console.log datum.name, "not implemented"
        activity = {}

      cacheObjects[datum._id] = activity
      overviewObjects.push overview

    cacheObjects.overview = overviewObjects
    callback cacheObjects

  @decorateFollows:(data, callback)->
    cacheObjects    = {}
    overviewObjects = []

    resp = (new FollowsBucketDecorator(data)).decorate()
    callback resp

    #cacheObjects[activity] = activity
    #overviewObjects.push overview
    #callback {cacheObjects, overviewObjects}

  @decorateInstalls:(data, callback)->
    resp = (new InstallsBucketDecorator(data)).decorate()
    callback resp

  @decorateMembers:(data, callback)->
    resp = (new NewMemberBucketDecorator(data)).decorate()
    callback resp

  ## TODO: move these to ResponseDecorator ##
  #@decorateFollows:(data, callback)->
    #{cacheObjects, overviewObjects} = @decorateFollowsToCacheObject data, callback
    #response = @decorateResponse cacheObjects, overviewObjects

    #callback response

  ## TODO: move these to ResponseDecorator ##
  @decorateResponse:(cacheObjects, overviewObjects)->
    return (new ResponseDecorator(cacheObjects, overviewObjects)).decorate()
