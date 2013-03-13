
{argv}      = require 'optimist'
{uri}       = require('koding-config-manager').load("main.#{argv.c}")
dateFormat  = require 'dateformat'

flags =
  comment           :
    definition      : "comment"
  likeActivities    :
    definition      : "like"
  followActions     :
    definition      : "follow"
  privateMessage    :
    definition      : "private message"

link      = (addr, text)   ->
  """<a href="#{addr}" #{Templates.linkStyle}>#{text}</a>"""
gravatar  = (m, size = 20) ->
  """<img width="#{size}px" height="#{size}px" style="border:none; margin-right:8px; float:left; margin-top:3px;"
          src="https://gravatar.com/avatar/#{m.sender.profile.hash}?size=#{size}&d=https%3A%2F%2Fapi.koding.com%2Fimages%2Fdefaultavatar%2Fdefault.avatar.#{size}.png" />"""

Templates =

  linkStyle    : """ style="text-decoration:none; color:#ff9200;" """
  mainTemplate : (m, content, footer, description)->

    description ?= ''
    currentDate  = dateFormat m.notification.dateIssued, "mmm dd"
    turnOffLink  = "#{uri.address}/Unsubscribe/#{m.notification.unsubscribeId}"

    """
      <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
        "http://www.w3.org/TR/REC-html40/loose.dtd">
        <html>
        <head><title>[Koding]</title></head>
        <body style="margin: 10px;">
          <table style="font-size: 13px; font-family: 'Open Sans', sans-serif;
                        height:100%; color: #666; width:100%;" cellspacing="0">
            <!-- HEADER -->
            <tr>
              <td style="width: 40px; text-align:right; border-right: 1px
                         solid #CCC; margin-left:12px; vertical-align:top;">
                <!-- Koding Logo with pure table -->
                <table width="28px" height="38px" style="margin-left:12px; text-align:right; height:38px; border:none; font-size:0px; " cellspacing="2">
                  <tr><td height="19%" style="height:19%; background-color:#FE6E00;" colspan="3">&nbsp;</td></tr>
                  <tr><td height="10%" style="height:10%; background-color:#403A32;" colspan="3">&nbsp;</td></tr>
                  <tr>
                      <td height="10%" style="height:10%; background-color:#403A32; width: 80%;" colspan="2">&nbsp;</td>
                      <td height="10%" style="height:10%; background-color:white; width: 20%;">&nbsp;</td>
                  </tr>
                  <tr><td height="10%" style="height:10%; background-color:#403A32;" colspan="3">&nbsp;</td></tr>
                  <tr><td height="10%" style="height:10%; background-color:#403A32;" colspan="3">&nbsp;</td></tr>
                  <tr>
                      <td height="10%" style="height:10%; background-color:#403A32; width: 80%;">&nbsp;</td>
                      <td height="10%" style="height:10%; background-color:white; width: 20%;" colspan="2">&nbsp;</td>
                  </tr>
                </table><br/>
              </td>
              <td style="padding: 6px 0 0 10px; padding-bottom:20px; margin-top: 0;">
                <h2 style="margin-top:0; ">Hello #{m.receiver.profile.firstName},</h2>
                <p>#{description}</p>
              </td>
              <td style="text-align:center; width:90px; vertical-align:top;">
                <p style="font-size: 11px; color: #999;
                          padding: 0 0 2px 0; margin-top: 4px;">#{currentDate}</p>
              </td>
            </tr>
            #{content}
            #{footer}
          </table>
        </body>
      </html>
    """

  footerTemplate : (turnOffLink)->
    """
    <!-- FOOTER -->
    <tr height="90%" style="height: 90%; ">
      <td style="width: 15px; border-right: 1px solid #CCC;"></td>
      <td height="40px" style="height:40px; padding-left: 10px;" colspan="2"></td>
    </tr>
    <tr style="font-size:11px; height: 30px; color: #999;">
      <td style="border-right: 1px solid #CCC; text-align:right;
                 padding-right:10px;"></td>
      <td style="padding-left: 10px;" colspan="2">
        #{turnOffLink} <br/>
        #{link "https://koding.com", "Koding"}, Inc. 358 Brannan, San Francisco, CA 94110
      </td>
    </tr>
    """

  singleEvent : (m)->

    action       = ''
    sender       = link "#{uri.address}/#{m.sender.profile.nickname}", \
                   "#{m.sender.profile.firstName} #{m.sender.profile.lastName}"
    avatar       = gravatar m
    activityTime = dateFormat m.notification.dateIssued, "HH:MM"
    preview      = """<div style="padding:10px; margin-left:28px; color:#777;
                                  margin-bottom:6px; margin-top: 4px;
                                  font-size:12px; background-color:#F8F8F8;
                                  border-radius:4px;">
                      #{m.realContent?.body}</div>"""

    "is started to following you"

    switch m.event
      when 'FollowHappened'
        action = "started following you."
        m.contentLink = ''
        preview = ''
      when 'LikeIsAdded'
        action = "liked your"
      when 'PrivateMessageSent'
        action = "sent you a"
      when 'ReplyIsAdded'
        if m.receiver.getId().equals m.subjectContent.data.originId
          action = "commented on your"
        else
          action = "also commented on"
          # FIXME GG Implement the details
          # if m.realContent.origin?._id is m.sender._id
          #   action = "#{action} own"

    """
      <tr style="vertical-align:top; background-color:white; color: #282623;">
        <td style="width: 40px; text-align:right; border-right: 1px solid #CCC;
                   color: #999; font-size:11px; line-height: 28px;
                   padding-right:10px;"><a href='#'
                   style='text-decoration:none; color:#999;pointer-event:none'>
                   #{activityTime}</a></td>
        <td style="padding-left: 10px; color: #666; " colspan="2">
            #{avatar}
            <div style="line-height: 20px; padding-left:28px; padding-top:4px;">
              #{sender} #{action} #{m.contentLink}
            </div>
            #{preview}
        </td>
      </tr>
    """

  instantMail  : (m)->
    turnOffLink = "#{uri.address}/Unsubscribe/#{m.notification.unsubscribeId}"
    eventName   = flags[m.notification.eventFlag].definition
    turnOffAllURL = link turnOffLink+"/all","all"
    turnOffSpecificType = link turnOffLink, eventName
    turnOffLink = """Unsubscribe from #{turnOffSpecificType} notifications / Unsubscribe from #{turnOffAllURL} emails from Koding."""
    Templates.mainTemplate m, \
      Templates.singleEvent(m), Templates.footerTemplate turnOffLink

  dailyMail    : (m, content)->
    turnOffLink = "#{uri.address}/Unsubscribe/#{m.notification.unsubscribeId}"
    turnOffDailyURL = link "#{turnOffLink}/daily", "daily emails"
    turnOffAllEmailsURL = link "#{turnOffLink}/all", "all"
    turnOffLink = """Unsubscribe from #{turnOffDailyURL} or Unsubscribe from #{turnOffAllEmailsURL} emails from Koding."""
    description = "Here what's happened in Koding today!"
    Templates.mainTemplate m, content, Templates.footerTemplate(turnOffLink), description

  commonHeader : (m)->
    eventName   = flags[m.notification.eventFlag].definition

    return """You have a new #{eventName}"""
  dailyHeader  : (m)->
    currentDate  = dateFormat m.notification.dateIssued, "mmm dd"
    return """Your Koding Activity for today: #{currentDate}"""

module.exports = Templates