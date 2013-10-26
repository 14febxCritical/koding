CBucketActivity = require '../../activity/bucketactivity'
CActivity = require '../../activity'

module.exports = class CGroupLeaverActivity extends CBucketActivity

  @share()

  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    sharedMethods   : CActivity.sharedMethods
    relationships   : CBucketActivity.relationships
