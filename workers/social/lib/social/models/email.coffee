{Model} = require 'bongo'

createId = require 'hat'
getUniqueId= -> createId 256

module.exports = class JMail extends Model

  @share()

  @set
    indexes          :
      status         : 'sparse'
    sharedMethods    :
      static         : ['unsubscribeWithId']
    sharedEvents     :
      instance       : []
      static         : []
    schema           :
      dateIssued     :
        type         : Date
        default      : -> new Date
      dateAttempted  : Date
      email          :
        type         : String
        email        : yes
      from           :
        type         : String
        email        : yes
        default      : 'hello@koding.com'
      replyto        :
        type         : String
        email        : yes
        default      : 'hello@koding.com'
      status         :
        type         : String
        default      : 'queued'
        enum         : ['Invalid status', ['queued', 'attempted', 'sending',
                                           'failed', 'unsubscribed']]
      force          :
        type         : Boolean
        default      : false
      subject        : String
      content        : String
      unsubscribeId  : String
      bcc            : String

  save:(callback)->
    @unsubscribeId = getUniqueId()+''  unless @_id? or @force
    super

  isUnsubscribed:(callback)->
    JUnsubscribedMail = require './unsubscribedmail'
    JUnsubscribedMail.isUnsubscribed @email, callback

  @unsubscribeWithId = (unsubscribeId, email, opt, callback)->
    JMail.one {email, unsubscribeId}, (err, mail)->
      return callback err  if err or not mail

      JUnsubscribedMail = require './unsubscribedmail'
      JUnsubscribedMail.one {email}, (err, unsubscribed)->
        return callback err  if err
        return callback null, 'Email was already unsubscribed'  if unsubscribed

        unsubscribed = new JUnsubscribedMail {email}
        unsubscribed.save (err)->
          callback err, unless err then 'Successfully unsubscribed' else null

  @fetchWithUnsubscribedInfo = (selector, options, callback)->
    JUnsubscribedMail = require './unsubscribedmail'

    JMail.some selector, options, (err, mails)->
      return callback err  if err

      emailsToCheck = (mail.email  for mail in mails when not mail.force)

      JUnsubscribedMail.some email: $in: emailsToCheck, {}, (err, uMails)->
        return callback err  if err

        unsubscribedEmails = (uMail.email  for uMail in uMails)

        cleanedMails = []
        for mail in mails
          unless mail.email in unsubscribedEmails
            cleanedMails.push mail
          else
            mail.update $set: {status: 'unsubscribed'}, (err)->
              # it's not fatal enough to break the process
              # also we don't wait for this to proceed with sending the emails
              # doing a callback(err) here can have unexpected outcomes
              console.log err  if err

        callback null, cleanedMails
