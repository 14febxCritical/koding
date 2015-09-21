kd                       = require 'kd'
React                    = require 'kd-react'
PublicChatPane           = require 'activity/components/publicchatpane'
PublicFeedPane           = require 'activity/components/publicfeedpane'
ChannelThreadPane        = require 'activity/components/channelthreadpane'
PostPane                 = require 'activity/components/postpane'
PrivateMessageThreadPane = require 'activity/components/privatemessagethreadpane'

module.exports = [
  {
    path: '/Channels'
    component: ChannelThreadPane
    childRoutes: [
      path: ':channelName'
      components:
        feed: null
        chat: PublicChatPane
        post: null
    ,
      path: ':channelName/summary'
      components:
        feed: PublicFeedPane
        chat: PublicChatPane
        post: null
    ,
      path: ':channelName/summary/:postSlug'
      components:
        feed: PublicFeedPane
        chat: PublicChatPane
        post: PostPane
    ,
      path: ':channelName/:postSlug'
      components:
        feed: null
        chat: PublicChatPane
        post: null
    ]
  },
  {
    path: '/Messages/:privateChannelId'
    component: PrivateMessageThreadPane
  }
]

