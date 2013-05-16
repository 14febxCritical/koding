neo4j = require "neo4j"

module.exports = class Neo4jHelper
  {Base, ObjectId, race, dash, secure} = require 'bongo'

  @fetchObjectsFromMongo:(collections, wantedOrder, callback)->
    sortThem=(err, objects)->
      if err
        callback(err)
        return
      ret = []
      for i in wantedOrder
        #console.log(i.idx + ' - ' + objects[i['idx']])
        ret.push(objects[i['idx']])
      callback null, ret

    ret = {}
    collectObjects = race (i, res, fin)->
      res.klass.all res.selector, (err, objects)->
        if err then callback err
        else
          for o in objects
            ret[o['_id'] + '_' + res.modelName] = o
        fin()
    , -> sortThem null, ret

    for modelName of collections
      ids = collections[modelName]
      klass = Base.constructors[modelName]
      selector = {
        _id:
          $in: ids.map (id)->
            if 'string' is typeof id then ObjectId(id)
            else id
      }
      collectObjects({klass:klass, selector:selector, modelName:modelName})

  @fetchFromNeo4j:(query, params, callback)->
    """ gets ids from neo4j, fetches objects from mongo, returns in the same order """
    neo4jConfig = KONFIG['neo4j']
    @db = new neo4j.GraphDatabase(neo4jConfig.host + ":" + neo4jConfig.port);
    #console.log("sending query to neo4j")
    @db.query query, params, (err, results)=>
      #console.log("got result from neo ???? " + err)
      if err
        console.log("error in neo4j query: " + err)
        return callback err

      if results.length == 0
        callback null, []

      # console.log(results)
      wants_in_order = []
      collections = {}
      for result in results
        # console.log("got result from neo4j")
        oid = result["items"]["_data"]["data"]["id"]
        otype = result["items"]["_data"]["data"]["name"]
        wants_in_order.push({id: oid, collection: otype, idx: oid+'_'+otype})
        collections[otype] ||= []
        collections[otype].push(oid)
      @fetchObjectsFromMongo(collections, wants_in_order, callback)

