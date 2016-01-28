kd                      = require 'kd'
React                   = require 'kd-react'
Link                    = require 'app/components/common/link'
ReactDOM                = require 'react-dom'
classnames              = require 'classnames'
ActivityFlux            = require 'activity/flux'
SidebarSection          = require 'app/components/sidebarsection'
isUserGroupAdmin        = require 'app/util/isusergroupadmin'
showErrorNotification   = require 'app/util/showErrorNotification'


module.exports = class SidebarNoStacks extends React.Component

  @defaultProps =
    className   : 'SidebarStackWidgets'


  constructor: ->

    @state =
      isGroupAdmin : no
      isReady      : no


  componentDidMount: ->

    isUserGroupAdmin (err, isAdmin) =>
      return showErrorNotification err  if err
      @setState
        isGroupAdmin : isAdmin
        isReady      : yes


  handleOnClick: (event) ->
    kd.utils.stopDOMEvent event
    ActivityFlux.actions.thread.switchToDefaultChannelForStackRequest()


  renderContent: ->

    if @state.isGroupAdmin
      <div>
        <label>No stacks</label>
        <Link href='/Admin/Stacks'>
          Create a stack
        </Link>
      </div>
    else
      <div>
        <p>
          Your stacks has not been
          fully configured yet, please
          contact your team admin.
        </p>
        <Link href='/Messages/New' onClick={@bound 'handleOnClick'}>
          Message admin
        </Link>
      </div>


  render: ->

    return null  unless @state.isReady

    <section className={classnames 'SidebarSection', @props.className}>
      <div className='SidebarSection-body'>
        {@renderContent()}
      </div>
    </section>

