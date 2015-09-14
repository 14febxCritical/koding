kd         = require 'kd'
React      = require 'kd-react'
proxifyUrl = require 'app/util/proxifyUrl'

module.exports = class EmbedBoxLinkImage extends React.Component

  @defaultProps =
    data   : {}
    width  : 100
    height : 100
    crop   : yes
    grow   : yes


  handleError: ->

    image = React.findDOMNode @refs.image
    image.className = 'hidden'


  render: ->

    { data, width, height, crop, grow } = @props
    { link_url, link_embed }            = data

    imageOptions = { width, height, crop, grow }
    srcUrl       = proxifyUrl link_embed.images?[0]?.url, imageOptions
    altText      = link_embed.title
    altText     += if link_embed.author_name then " by #{link_embed.author_name}" else '' 

    <a href={link_url} target='_blank' className='EmbedBoxLinkImage'>
      <img
        src       = { srcUrl }
        alt       = { altText }
        title     = { altText }
        className = 'EmbedBoxLinkImage'
        ref       = 'image'
        onError   = { @bound 'handleError' }
      />
    </a>

