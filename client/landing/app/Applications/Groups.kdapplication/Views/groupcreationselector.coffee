class GroupCreationSelector extends KDInputRadioGroup

  setDomElement:->
    options = @getOptions()
    @domElement = $ "<fieldset class='#{@utils.curry 'radiogroup kdinput', options.cssClass}'></fieldset>"

    for radioOptions, i in options.radios
      radioOptions.visible   ?= yes
      radioOptions.callback or= ->

      bg       = $ "<figure/>",
        class  : "kd-#{@getType()}-holder #{options.cssClassPrefix}#{@utils.slugify radioOptions.value}"
      div      = $ "<div/>"
      radio    = $ "<input/>",
        type   : @getType()
        name   : options.name
        value  : radioOptions.value
        class  : "no-kdinput hidden"
        id     : "#{@getId()}_#{@getType()}_#{i}"
      label    = $ "<span/>",
        html   : radioOptions.title
        class  : options.cssClassPrefix + @utils.slugify radioOptions.value
      icon     = $ "<cite/>",
        class  : "icon"
        text   : radioOptions.value

      bg.append  div
      div.append radio
      div.append icon
      div.append label
      @domElement.append bg

      bg.hide()  unless radioOptions.visible

    return @domElement

  click:(event)->
    input = $(event.target).closest(".kd-#{@getType()}-holder").find('input')
    return  unless input.length
    @setValue input[0].getAttribute "value"

class HostCreationSelector extends GroupCreationSelector

  setDomElement:->
    options = @getOptions()
    @domElement = $ "<fieldset class='#{@utils.curry 'radiogroup kdinput', options.cssClass}'></fieldset>"

    for radioOptions, i in options.radios
      radioOptions.visible   ?= yes
      radioOptions.callback or= ->

      bg       = $ "<figure/>",
        class  : "kd-#{@getType()}-holder #{options.cssClassPrefix}#{@utils.slugify radioOptions.value}"
      div      = $ "<div/>"
      radio    = $ "<input/>",
        type   : @getType()
        name   : options.name
        value  : radioOptions.value
        class  : "no-kdinput hidden"
        id     : "#{@getId()}_#{@getType()}_#{i}"
      label    = $ "<span/>",
        html   : radioOptions.title
        class  : options.cssClassPrefix + @utils.slugify radioOptions.value
      icon     = $ "<cite/>",
        class  : "icon"
        html   : "$<b>#{radioOptions.feeMonthly}</b>/mo"

      bg.append  div
      div.append radio
      div.append icon
      div.append label
      @domElement.append bg

      bg.hide()  unless radioOptions.visible

    return @domElement
