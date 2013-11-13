CActivity = require '../../activity'

module.exports = class CTutorialActivity extends CActivity

  @trait __dirname, '../../../traits/grouprelated'

  @share()

  @set
    encapsulatedBy  : CActivity
    sharedMethods   : CActivity.sharedMethods
    sharedEvents    : CActivity.sharedEvents
    schema          : CActivity.schema
    relationships   :
      subject       :
        targetType  : "JTutorial"
        as          : 'content'