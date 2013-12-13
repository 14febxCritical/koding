class EmbedBoxLinkDisplayView extends JView

  constructor:(options={}, data)->
    super options, data

    if data?.link_embed?.images?[0]?
      @embedImage = new EmbedBoxLinkViewImage
        cssClass : 'preview-image'
        delegate : this
      ,data
    else
      @embedImage = new KDCustomHTMLView 'hidden'

    @embedContent = new EmbedBoxLinkViewContent
      cssClass  : 'preview-text'
      delegate  : this
    , data

  pistachio:->
    """
    <div class="embed embed-link-view custom-link clearfix">
      {{> @embedImage}}
      {{> @embedContent}}
    </div>
    """
