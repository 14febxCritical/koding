# Methods shared by JAccount & JGuest
module.exports =
  sharedStaticMethods:->
    [
      'one', 'some', 'cursor', 'each', 'someWithRelationship'
      'someData', 'getAutoCompleteData', 'count'
      'byRelevance', 'fetchVersion','reserveNames'
      'impersonate', 'fetchBlockedUsers', 'fetchCachedUserCount'
    ]
  sharedInstanceMethods:->
    [
      'modify','follow','unfollow','fetchFollowersWithRelationship'
      'countFollowersWithRelationship', 'countFollowingWithRelationship'
      'fetchFollowingWithRelationship', 'fetchTopics'
      'fetchMounts','fetchActivityTeasers','fetchRepos','fetchDatabases'
      'fetchMail','fetchNotificationsTimeline','fetchActivities'
      'fetchStorage','count','addTags','fetchLimit', 'fetchLikedContents'
      'fetchFollowedTopics', 'fetchKiteChannelId', 'setEmailPreferences'
      'fetchNonces', 'glanceMessages', 'glanceActivities', 'fetchRole'
      'fetchAllKites','flagAccount','unflagAccount','isFollowing'
      'fetchFeedByTitle', 'updateFlags','fetchGroups','fetchGroupRoles',
      'setStaticPageVisibility','addStaticPageType','removeStaticPageType',
      'setHandle','setAbout','fetchAbout','setStaticPageTitle',
      'setStaticPageAbout', 'addStaticBackground', 'setBackgroundImage',
      'fetchGroupsWithPendingInvitations', 'fetchGroupsWithPendingRequests',
      'cancelRequest', 'acceptInvitation', 'ignoreInvitation',
      'fetchMyGroupInvitationStatus', 'fetchMyPermissions',
      'fetchMyPermissionsAndRoles', 'fetchMyFollowingsFromGraph',
      'fetchMyFollowersFromGraph', 'blockUser',
      'sendEmailVMTurnOnFailureToSysAdmin', 'fetchRelatedTagsFromGraph',
      'fetchRelatedUsersFromGraph', 'fetchDomains', 'fetchDomains',
      'unlinkOauth', 'changeUsername', 'fetchOldKodingDownloadLink',
      'markUserAsExempt', 'checkFlag', 'userIsExempt', 'checkGroupMembership',
      'getOdeskAuthorizeUrl'
    ]
