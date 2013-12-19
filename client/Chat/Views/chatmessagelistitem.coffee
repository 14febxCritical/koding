class ChatMessageListItem extends KDListItemView

  constructor:(options = {}, data)->

    options.cssClass = KD.utils.curry "message", data.cssClass
    options.tagName  = "li"
    data.message     = KD.utils.xssEncode data.message
    super options, data

    @timeWidget = new KDTimeAgoView
      cssClass : 'time-widget'
    , new Date

  viewAppended:->
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
       {{>@timeWidget}}
       <strong>{{ #(sender) }}</strong><hr/>
       {{ #(message) }}
    """

  addMessage:(message)->
    @data.message += "<br/>#{KD.utils.xssEncode message}"
    @render()
