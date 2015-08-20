actions         = require '../actions/actiontypes'
immutable       = require 'immutable'
toImmutable     = require 'app/util/toImmutable'
KodingFluxStore = require 'app/flux/store'

module.exports = class UsersStore extends KodingFluxStore

  @getterPath = 'UsersStore'

  getInitialState: -> immutable.Map()

  initialize: ->

    @on actions.LOAD_USER_SUCCESS, @handleLoadSuccess
    @on actions.SEARCH_USERS_SUCCESS, @handleLoadListSuccess

    @on actions.MARK_USER_AS_TROLL_BEGIN, @handleMarkUserAsTrollBegin
    @on actions.MARK_USER_AS_TROLL_SUCCESS, @handleMarkUserAsTrollSuccess
    @on actions.MARK_USER_AS_TROLL_FAIL, @handleMarkUserAsTrollFail

    @on actions.UNMARK_USER_AS_TROLL_BEGIN, @handleUnmarkUserAsTrollBegin
    @on actions.UNMARK_USER_AS_TROLL_SUCCESS, @handleUnmarkUserAsTrollSuccess
    @on actions.UNMARK_USER_AS_TROLL_FAIL, @handleUnmarkUserAsTrollFail

    @on actions.BLOCK_USER_BEGIN, @handleBlockUserBegin
    @on actions.BLOCK_USER_SUCCESS, @handleBlockUserSuccess
    @on actions.BLOCK_USER_FAIL, @handleBlockUserFail


  ###*
   * Load account.
   *
   * @param {Immutable.Map} users
   * @param {object} payload
   * @param {string} payload.id
   * @param {JAccount} payload.account
  ###
  handleLoadSuccess: (users, { id, account }) ->

    return users.set id, toImmutable account


  ###*
   * Load account list.
   *
   * @param {Immutable.Map} currentUsers
   * @param {object} payload
   * @param {array} payload.users
  ###
  handleLoadListSuccess: (currentUsers, { users }) ->

    return currentUsers.withMutations (map) ->
      map.set user._id, toImmutable user for user in users
      return map


  ###*
   * Handler for MARK_USER_AS_TROLL_BEGIN action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleMarkUserAsTrollBegin: (users, account) -> users


  ###*
   * Handler for MARK_USER_AS_TROLL_SUCCESS action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleMarkUserAsTrollSuccess: (users, account) ->

    accountId = account._id

    if users.has accountId
      user = users.get accountId
      user = user.set 'isExempt', yes
      return users.set accountId, user


  ###*
   * Handler for MARK_USER_AS_TROLL_FAIL action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} payload
   * @param {string} payload.err
   * @param {object} payload.account
  ###
  handleMarkUserAsTrollFail: (users, { err, account }) -> users


  ###*
   * Handler for UNMARK_USER_AS_TROLL_BEGIN action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleUnmarkUserAsTrollBegin: (users, account) -> users


  ###*
   * Handler for UNMARK_USER_AS_TROLL_SUCCESS action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleUnmarkUserAsTrollSuccess: (users, account) ->

    accountId = account._id

    if users.has accountId
      user = users.get accountId
      user = user.set 'isExempt', no
      return users.set accountId, user


  ###*
   * Handler for UNMARK_USER_AS_TROLL_FAIL action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} payload
   * @param {object} payload.err
   * @param {object} payload.account
  ###
  handleUnmarkUserAsTrollFail: (users, { err, account }) -> users


  ###*
   * Handler for BLOCK_USER_BEGIN action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleBlockUserBegin: (users, account) -> users


  ###*
   * Handler for BLOCK_USER_SUCCESS action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleBlockUserSuccess: (users, account) -> users


  ###*
   * Handler for BLOCK_USER_FAIL action.
   * It sets state's value as given given account.
   *
   * @param {Immutable.Map} users
   * @param {object} account
  ###
  handleBlockUserFail: (users, account) -> users

