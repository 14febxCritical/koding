class GlobalNotificationView extends JView

  constructor:->

    super

    @close = new CustomLinkView
      title      : ''
      icon       :
        cssClass : 'close'
      click      : (event)=>
        KD.utils.stopDOMEvent event
        @hideAndDestroy()

    @bindTransitionEnd()

    {scheduledAt, closeTimer} = @getData()

    scheduledAt = (new Date(scheduledAt)).getTime()

    if closeTimer and typeof closeTimer is 'number'
      KD.utils.wait closeTimer, @bound 'hideAndDestroy'

    @timer = new KDCustomHTMLView
      tagName  : 'strong'
      cssClass : if @getOption 'showTimer' then 'hidden'
      partial  : @timerPartial scheduledAt

    @repeater = KD.utils.repeat 2000, =>
      @timer.updatePartial @timerPartial scheduledAt
      KD.utils.killRepeat @repeater  if Date.now() > scheduledAt

    if 'admin' in KD.config.roles and @getData().bongo_
      @adminClose = new KDButtonView
        tagName  : 'span'
        cssClass : 'solid red mini cancel'
        title    : 'ADMIN: Cancel Notification'
        callback : =>
          @getData().cancel (err)=>
            if err then KD.notify_ err
            else @hideAndDestroy()
    else
      @adminClose = new KDCustomHTMLView

    @getData().on? 'restartCanceled', =>
      log 'remove active restart message ::realtime::'
      @hideAndDestroy()

  hideAndDestroy:->
    @once 'transitionend', @bound 'destroy'
    @hide()

  destroy:->

    KD.utils.killRepeat @repeater
    super


  timerPartial:(time)-> "#{KD.utils.nicetime (time - Date.now()) / 1000}."

  show:-> @setClass 'in'

  hide:-> @unsetClass 'in'

  pistachio:->
    """
    <div>
    {{ #(title)}} {{> @timer}} {cite{ #(content)}}
    {{> @close}}{{> @adminClose}}
    </div>
    """