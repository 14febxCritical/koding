kd                       = require 'kd'
React                    = require 'kd-react'
immutable                = require 'immutable'
SidebarList              = require 'app/components/sidebarlist'
SidebarSection           = require 'app/components/sidebarsection'
SidebarChannelsListItem  = require 'app/components/sidebarchannelslistitem'
Link                     = require 'app/components/common/link'


module.exports = class SidebarChannelsSection extends React.Component

  @defaultProps =
    selectedId   : null
    threads      : immutable.Map()
    previewCount : 0


  renderMoreLink: ->

    { threads, previewCount } = @props

    if threads.size > previewCount
      <Link className="SidebarList-showMore" href="/AllChannels">More ...</Link>


  render: ->

    <SidebarSection
      title="Channels"
      titleLink="/AllChannels"
      secondaryLink="/NewChannel"
      className="SidebarChannelsSection">
      <SidebarList
        previewCount={@props.previewCount}
        itemComponent={SidebarChannelsListItem}
        componentProp='SidebarChannelsListItem'
        threads={@props.threads}
        selectedId={@props.selectedId} />
      {@renderMoreLink()}
    </SidebarSection>


