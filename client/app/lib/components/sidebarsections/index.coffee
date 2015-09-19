kd                     = require 'kd'
React                  = require 'kd-react'
ActivityFlux           = require 'activity/flux'
KDReactorMixin         = require 'app/flux/reactormixin'
SidebarChannelsSection = require 'app/components/sidebarchannelssection'
SidebarMessagesSection = require 'app/components/sidebarmessagessection'


module.exports = class SidebarSections extends React.Component

  PREVIEW_COUNT = 10

  { getters, actions } = ActivityFlux

  getDataBindings: ->
    return {
      publicChannels          : getters.followedPublicChannelThreads
      privateChannels         : getters.followedPrivateChannelThreads
      selectedThreadId        : getters.selectedChannelThreadId
      filteredPublicChannels  : getters.filteredPublicChannels
      filteredPrivateChannels : getters.filteredPrivateChannels
    }


  componentDidMount: ->
    actions.channel.loadFollowedPublicChannels()
    actions.channel.loadFollowedPrivateChannels()


  renderChannelsSection: ->
    <SidebarChannelsSection
      previewCount={PREVIEW_COUNT}
      selectedId={@state.selectedThreadId}
      threads={@state.filteredPublicChannels.followed} />


  renderMessagesSection: ->
    <SidebarMessagesSection
      previewCount={PREVIEW_COUNT}
      selectedId={@state.selectedThreadId}
      threads={@state.filteredPrivateChannels.followed} />


  render: ->
    <div className="SidebarSections">
      {@renderChannelsSection()}
      {@renderMessagesSection()}
    </div>


React.Component.include.call SidebarSections, [KDReactorMixin]
