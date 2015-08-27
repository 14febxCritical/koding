$              = require 'jquery'
kd             = require 'kd'
React          = require 'kd-react'
dateFormat     = require 'dateformat'
Tooltip        = require 'app/components/tooltip'
Portal         = require 'react-portal'

module.exports = class MessageTime extends React.Component

  @propTypes =
    date : React.PropTypes.string.isRequired


  timeFormat            = 'h:MM TT'
  timeWithSecondsFormat = 'h:MM:ss TT'

  getTime: (date) ->

    dateFormat date, timeFormat


  setTooltipPosition: (e) ->

    MessageDateDOMNode = @refs.MessageDate.getDOMNode()
    offset = $(MessageDateDOMNode).offset()

    @setState
      tooltipY      : offset.top
      tooltipX      : offset.left + MessageDateDOMNode.offsetWidth / 2

  getItemProps: ->
    onMouseEnter: (e)=>
      @tooltipShouldBeVisible = yes
      @setTooltipOpenState(300)
    onMouseLeave: =>
      @tooltipShouldBeVisible = no
      @setTooltipOpenState(100)


  getTooltipTitle: (data, timeFormat) ->

    relativeDates  = ["Today", "Yesterday"]
    today          = new Date
    givenDate      = new Date @props.date
    dateDifference = today.getDate() - givenDate.getDate()
    dateString     = relativeDates[dateDifference] or dateFormat givenDate, "dddd, mmmm d"
    dateString     = "#{dateString} at #{dateFormat givenDate, timeFormat}"


  render: ->

    <div className='ChatItem-messageDate' {...@getItemProps()} ref='MessageDate'>
      <time>{ @getTime @props.date }</time>
      <Portal isOpened={ @state.isTooltipOpen }>
        <Tooltip text={ @getTooltipTitle @props.date, timeWithSecondsFormat } tooltipX={@state.tooltipX} tooltipY={@state.tooltipY}/>
      </Portal>
    </div>

