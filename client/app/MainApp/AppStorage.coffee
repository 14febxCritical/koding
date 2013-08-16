
class AppStorage extends KDEventEmitter

  constructor: (appId, version)->
    @_applicationID = appId
    @_applicationVersion = version
    @reset()
    super

  storageFetched: (callback)->
    if @_storage then callback()
    else @once "storageFetched", -> callback()

  fetchStorage: (callback = noop)->

    [appId, version] = [@_applicationID, @_applicationVersion]

    unless @_storage
      KD.whoami().fetchStorage {appId, version}, (error, storage) =>
        unless error
          callback @_storage = storage or {appId, version, bucket:{}}
          @emit "storageFetched"
        else
          callback null

    else
      callback @_storage
      KD.utils.defer => @emit "storageFetched"

  fetchValue: (key, callback, group = 'bucket')->

    @reset()
    @fetchStorage (storage)=>
      callback if storage[group]?[key] then storage[group][key]

  getValue: (key, group = 'bucket')->

    return unless @_storage
    return if @_storageData[group]?[key]? then @_storageData[group][key]
    return if @_storage[group]?[key]? then @_storage[group][key]

  setValue: (key, value, callback, group = 'bucket')->

    pack = @zip key, group, value

    @_storageData[group] = {}  unless @_storageData[group]?
    @_storageData[group][key] = value

    @fetchStorage (storage)=>
      storage.update {
        $set: pack
      }, callback

  unsetKey: (key, callback, group = 'bucket')->

    pack = @zip key, group, 1

    @fetchStorage (storage)=>
      delete @_storageData[group]?[key]
      storage.update {
        $unset: pack
      }, callback

  reset: ->
    @_storage = null
    @_storageData = {}

  zip: (key, group, value) ->

    pack = {}
    _key = group+'.'+key
    pack[_key] = value
    pack

class AppStorageController extends KDController

  constructor:->
    super
    @appStorages = {}

  storage:(appName, version)->

    if @appStorages[appName]?
      storage = @appStorages[appName]
    else
      storage = @appStorages[appName] = new AppStorage appName, version

    storage.fetchStorage()
    return storage

# Let people can use AppStorage
KD.classes.AppStorage = AppStorage