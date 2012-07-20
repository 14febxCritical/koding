class Notifying
  
  {ObjectRef} = bongo
  {Relationship} = jraphical
  
  @getNotificationEmail =-> 'hi@koding.com'
  
  @getNotificationSubject =-> 'You have pending notifications.'
  
  @getNotificationBody =(event, contents)-> 
    """
    event name: #{event};
    contents: #{JSON.stringify(contents)};
    """
  
  setNotifiers:(events, listener)->
    events.forEach (event)=> @on event, listener.bind null, event
  
  notifyAll:(receivers, event, contents)->
    receivers.forEach (receiver)=>
      @notify receiver, event, contents
  
  notify:(receiver, event, contents)->
    actor = contents[contents.actorType]
    {origin} = contents
    if actor? and not receiver.getId().equals actor.id
      receiver?.sendNotification? event, contents
    relationship = new Relationship contents.relationship
    CBucket.addActivities relationship, origin, actor, (err)->
      if receiver instanceof JAccount
        username = receiver.getAt('profile.nickname')
        JUser.someData {username}, {email: 1}, (err, cursor)->
          if err
            console.log "Could not load user record for #{username}"
          else cursor.nextObject (err, user)->
            {email} = user
            notification = new JEmailNotification(
              email
              receiver
              event
              contents
            )
            notification.save (err)->
              if err
                console.log "There was an error saving the notification.", err, err.errors

  notifyOriginWhen:(events...)->
    @setNotifiers events, (event, contents)=>
      @notify contents.origin, event, contents

  notifyFollowersWhen:(events...)->
    @setNotifiers events, (event, contents)=>
      {origin} = contents
      @fetchFollowers (err, followers)=>
        if err then console.log 'Could not fetch followers.'
        else
          receivers = followers.filter (follower)->
            follower? and not follower.equals? origin
          @notifyAll receivers, event, contents