module.exports =

    member      :
      following :
        """
          START group=node:koding(id={groupId})
          MATCH group-[r:member]->members-[:follower]->currentUser
          WHERE currentUser.id = {currentUserId}
          RETURN members
          ORDER BY {orderByQuery} DESC
          SKIP {skipCount}
          LIMIT {limitCount}
        """
      follower  :
        """
          START group=node:koding(id={groupId})
          MATCH group-[r:member]->members<-[:follower]-currentUser
          WHERE currentUser.id = {currentUserId}
          RETURN members
          ORDER BY {orderByQuery} DESC
          SKIP {skipCount}
          LIMIT {limitCount}
        """
      list: (exemptClause)->
        """
          START group=node:koding(id={groupId})
          MATCH group-[r:member]->members
          WHERE members.name="JAccount"
          #{exemptClause}
          RETURN members
          ORDER BY {orderByQuery} DESC
          SKIP {skipCount}
          LIMIT {limitCount}
        """
      count: (exemptClause)->
        """
        START group=node:koding(id={groupId})
        MATCH group-[:member]->members
        WHERE members.name="JAccount"
        #{exemptClause}
        RETURN count(members) as count
        """

      search: (options)->
        {seed, firstNameRegExp, lastNameRegexp, blacklistQuery, exemptClause} = options
        """
          START koding=node:koding(id={groupId})
          MATCH koding-[r:member]->members

          WHERE  (
            members.`profile.nickname` =~ '(?i)#{seed}'
            or members.`profile.firstName` =~ '(?i)#{firstNameRegExp}'
            or members.`profile.lastName` =~ '(?i)#{lastNameRegexp}'
          )

          #{blacklistQuery}
          #{exemptClause}

          RETURN members
          ORDER BY members.`profile.firstName`
          SKIP {skipCount}
          LIMIT {limitCount}
        """
    bucket      :
      newMembers :
        """
          START group=node:koding(id={groupId})
          MATCH group-[r:member]->members
          WHERE r.createdAtEpoch < {to}
          RETURN members
          ORDER BY r.createdAtEpoch DESC
          LIMIT 20
        """
      newInstallations :
        """
          START group=node:koding(id={groupId})
          MATCH group-[:member]->users<-[r:user]-apps
          WHERE apps.name="JApp"
          AND r.createdAtEpoch < {to}
          RETURN users, apps, r
          ORDER BY r.createdAtEpoch DESC
          LIMIT 20
        """
      newUserFollows :
        """
          START group=node:koding(id={groupId})
          MATCH group-[:member]->followees<-[r:follower]-follower
          WHERE follower<-[:member]-group
          AND r.createdAtEpoch < {to}
          RETURN r,followees, follower
          ORDER BY r.createdAtEpoch DESC
          LIMIT 20
        """
      newTagFollows :
        """
          START koding=node:koding(id={groupId})
          MATCH koding-[:member]->followees<-[r:follower]-follower
          WHERE follower.name="JTag"
            AND follower.group = {groupName}
            AND r.createdAtEpoch < {to}
          RETURN r,followees, follower
          ORDER BY r.createdAtEpoch DESC
          LIMIT 20
        """
    activity    :
      public :(facetQuery="",groupFilter="", exemptClause="")->
        """
          START group=node:koding(id={groupId})
          MATCH group-[:member]->members<-[:author]-content
          WHERE content.`meta.createdAtEpoch` < {to}
          #{facetQuery}
          #{groupFilter}
          #{exemptClause}
          RETURN content
          ORDER BY content.`meta.createdAtEpoch` DESC
          LIMIT {limitCount}
        """

      following:(facet="", timeQuery="", exemptClause="")->
        """
          START member=node:koding(id={userId})
          MATCH member<-[:follower]-members-[:author]-content
          WHERE members.name="JAccount"
          AND content.group = {groupName}
          #{facet}
          #{timeQuery}
          #{exemptClause}
          RETURN DISTINCT content
          ORDER BY content.`meta.createdAtEpoch` DESC
          LIMIT {limitCount}
        """

      profilePage: (options)->
        """
          START member=node:koding(id={userId})
          MATCH member<-[:author]-content
          WHERE content.`meta.createdAtEpoch` < {to}
          #{options.facetQuery}
          RETURN DISTINCT content
          ORDER BY #{options.orderBy} DESC
          LIMIT {limitCount}
        """

    invitation  :
      list     :(status, timestampQuery="", searchQuery="")->
        """
          START group=node:koding(id={groupId})
          MATCH group-[r:owner]->groupOwnedNodes
          WHERE groupOwnedNodes.name = 'JInvitationRequest'
          AND groupOwnedNodes.status IN #{status}
          #{timestampQuery}
          #{searchQuery}
          RETURN groupOwnedNodes
          ORDER BY groupOwnedNodes.`meta.createdAtEpoch`
          LIMIT {limitCount}
        """
    aggregation :
      relationshipCount:(relationshipName)->
        """
          START group=node:koding(id={groupId})
          MATCH group-[:#{relationshipName}]->items
          RETURN count(items) as count
        """

