kd          = require 'kd'
actionTypes = require './actiontypes'

{ actions: appActions } = require 'app/flux'


dispatch = (args...) -> kd.singletons.reactor.dispatch args...


###*
 * Action to set current query of chat input users.
 * Also, it resets users selected index and loads users
 * filtered by query if query is not empty
 *
 * @param {string} stateId
 * @param {string} query
###
setQuery = (stateId, query) ->

  if query
    { SET_CHAT_INPUT_USERS_QUERY } = actionTypes
    dispatch SET_CHAT_INPUT_USERS_QUERY, { stateId, query }
    resetSelectedIndex stateId
    appActions.user.searchAccounts query
  else
    unsetQuery stateId


###*
 * Action to unset current query of chat input users.
 * Also, it resets users selected index
 *
 * @param {string} stateId
###
unsetQuery = (stateId) ->

  { UNSET_CHAT_INPUT_USERS_QUERY } = actionTypes
  dispatch UNSET_CHAT_INPUT_USERS_QUERY, { stateId }

  resetSelectedIndex stateId


###*
 * Action to set selected index of chat input users
 *
 * @param {string} stateId
 * @param {number} index
###
setSelectedIndex = (stateId, index) ->

  { SET_CHAT_INPUT_USERS_SELECTED_INDEX } = actionTypes
  dispatch SET_CHAT_INPUT_USERS_SELECTED_INDEX, { stateId, index }


###*
 * Action to increment users selected index
 *
 * @param {string} stateId
###
moveToNextIndex = (stateId) ->

  { MOVE_TO_NEXT_CHAT_INPUT_USERS_INDEX } = actionTypes
  dispatch MOVE_TO_NEXT_CHAT_INPUT_USERS_INDEX, { stateId }


###*
 * Action to decrement users selected index
 *
 * @param {string} stateId
###
moveToPrevIndex = (stateId) ->

  { MOVE_TO_PREV_CHAT_INPUT_USERS_INDEX } = actionTypes
  dispatch MOVE_TO_PREV_CHAT_INPUT_USERS_INDEX, { stateId }


###*
 * Action to reset users selected index
 *
 * @param {string} stateId
###
resetSelectedIndex = (stateId) ->

  { RESET_CHAT_INPUT_USERS_SELECTED_INDEX } = actionTypes
  dispatch RESET_CHAT_INPUT_USERS_SELECTED_INDEX, { stateId }


###*
 * Action to set visibility of chat input users
 *
 * @param {string} stateId
 * @param {bool} visible
###
setVisibility = (stateId, visible) ->

  { SET_CHAT_INPUT_USERS_VISIBILITY } = actionTypes
  dispatch SET_CHAT_INPUT_USERS_VISIBILITY, { stateId, visible }


module.exports = {
  setQuery
  unsetQuery
  setSelectedIndex
  moveToNextIndex
  moveToPrevIndex
  resetSelectedIndex
  setVisibility
}