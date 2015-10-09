kd           = require 'kd'
React        = require 'kd-react'
immutable    = require 'immutable'
ActivityFlux = require 'activity/flux'
classnames   = require 'classnames'


module.exports = class DropupItem extends React.Component

  @defaultProps =
    item       : immutable.Map()
    isSelected : no
    index      : 0
    className  : ''


  handleSelect: ->

    { onSelected, index } = @props
    onSelected? index


  handleClick: ->

    { onConfirmed, item } = @props
    onConfirmed? item


  getClassName: ->

    { isSelected, className } = @props

    classes =
      'DropupItem'          : yes
      'DropupItem-selected' : isSelected
    classes[className]      = yes  if className

    return classnames classes


  render: ->

    className = @getClassName()

    <div
      className    = {className}
      onMouseEnter = {@bound 'handleSelect'}
      onClick      = {@bound 'handleClick'}
    >
      {@props.children}
    </div>

