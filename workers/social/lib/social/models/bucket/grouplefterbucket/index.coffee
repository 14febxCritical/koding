CBucket = require '../index'

module.exports = class CGroupLefterBucket extends CBucket

  @share()

  @set
    schema          : CBucket.schema
