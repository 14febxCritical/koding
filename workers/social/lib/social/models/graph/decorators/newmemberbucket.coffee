BucketActivityDecorator = require './bucketactivity'

module.exports = class NewMemberBucketDecorator extends BucketActivityDecorator
  _ = require 'underscore'

  constructor:(@data)->
    @activityName  = 'CNewMemberBucketActivity'
    @bucketName    = 'CNewMemberBucket'
    @overview      = {createdAt:[], ids:[], type:@activityName, count:1}
    @overviewIndex = {}

  decorate:->
    return {overview:[]}  if @data.length is 0

    members  = {}
    overview = []

    data = _.sortBy @data, (member)-> member.data.meta.createdAt
    data = data.reverse()

    for member in data
      member = member.data
      id = member.id
      generatedMember = {}
      generatedMember.modifiedAt = member.meta.createdAt
      generatedMember.createdAt  = member.meta.createdAt
      generatedMember.type       = @activityName
      generatedMember._id        = id
      snapshot = @generateSnapshot member
      generatedMember.snapshot   = JSON.stringify snapshot
      generatedMember.ids        = [id]
      generatedMember.sorts      = {repliesCount: 0, likesCount: 0, followerCount: 0}
      members[id] =  generatedMember
      @addToOverview(member)

    members.overview = [@overview]

    return members

  addToOverview:(member)->
    return  if @overview.count > 3
    @overview.count++
    @overview.createdAt.unshift member.meta.createdAt.toJSON()
    @overview.ids.unshift member.id

  generateSnapshot:(member)->
    snapshot = {}
    snapshot._id         = member.id
    snapshot.sourceName  = "JAccount"

    bongo = {constructorName : @bucketName}
    snapshot.bongo_      = bongo
    snapshot.meta        = member.meta
    snapshot.group       = []

    anchor =
      bongo_ : { constructorName : "ObjectRef" }
      constructorName : "JAccount"
      id : member.id

    snapshot.anchor      = anchor
    return snapshot
