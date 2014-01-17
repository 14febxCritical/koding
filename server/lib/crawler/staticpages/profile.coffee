{argv} = require 'optimist'
{uri} = require('koding-config-manager').load("main.#{argv.c}")

createLinkToStatusUpdate = (createDate, slug) ->
  content =
    """
    <a href="#{uri.address}/#!/Activity/#{slug}"><time class="kdview">#{createDate}</time></a>
    """
  return content

createStatusUpdateNode = (statusUpdate, authorFullName, authorNickname)->
  { formatDate } = require '../helpers'
  createdAt = ""
  if statusUpdate?.meta?.createdAt?
    createdAt = formatDate statusUpdate.meta.createdAt

  slug = ""
  slug = statusUpdate.slug  if statusUpdate?.slug?

  linkToStatusUpdate = createLinkToStatusUpdate createdAt, slug

  commentsList = ""
  if statusUpdate?.replies
    for comment in statusUpdate.replies
      console.log comment
      avatarUrl = "https://gravatar.com/avatar/#{comment.author.hash}?size=90&amp;d=https%3A%2F%2Fapi.koding.com%2Fimages%2Fdefaultavatar%2Fdefault.avatar.40.png"
      commentsList +=
        """
          <div class="kdview kdlistitemview kdlistitemview-comment">
            <a class="avatarview online" href="/#{comment.author.nickname}" style="width: 40px; height: 40px; background-size: 40px; background-image: none;"><img class="" width="40" height="40" src="#{avatarUrl}" style="opacity: 1;"></a>
            <div class="comment-contents clearfix">
              <a class="profile" href="/#{comment.author.nickname}">#{comment.author.firstName} #{comment.author.lastName}</a>
              <div class="comment-body-container"><p>#{comment.body}</p></div>

            </div>
          </div>
        """

  commentsContent =
    """
      <div class="kdview comment-container commented">
        <div class="kdview listview-wrapper">
          <div class="kdview kdscrollview">
            <div class="kdview kdlistview kdlistview-comments">
              #{commentsList}
            </div>
          </div>
        </div>
      </div>
    """

  statusUpdateContent = ""
  if statusUpdate?.body
    statusUpdateContent =
    """
    <div class="kdview activity-item status">
      <a class="profile" href="/#{authorNickname}">#{authorFullName}</a>
      <article data-paths="body" id="el-1223">
        <p>#{statusUpdate.body}</p>
      </article>
      <footer>#{linkToStatusUpdate}</footer>
      #{commentsContent}
    </div>
    """
  return statusUpdateContent

createLinkToUserProfile = (fullName, nickname) ->
  content =
    """
      <a href=\"#{uri.address}/#!/#{nickname}\">#{fullName}</a>
    """
  return content

getStatusUpdates = (statusUpdates, authorFullName, authorNickname) ->
  linkToProfile = createLinkToUserProfile authorFullName, authorNickname
  if statusUpdates?.length > 0
    updates = (createStatusUpdateNode(statusUpdate, authorFullName, authorNickname) for statusUpdate in statusUpdates)
    updatesContent = updates.join("")
  else
    updatesContent = ""
  return updatesContent


module.exports = (account, statusUpdates)->
  getStyles  = require './styleblock'
  getGraphMeta  = require './graphmeta'
  { formatDate, getFullName } = require '../helpers'

  {profile:{nickname}} = account if account
  fullName = getFullName account
  sUpdates = getStatusUpdates statusUpdates, fullName, nickname, (err, sUpdates) ->
  """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <title>#{nickname} - Koding</title>
    #{getGraphMeta()}
  </head>
    <body class='koding profile' itemscope itemtype="http://schema.org/WebPage">
      #{putContent(account, sUpdates)}
    </body>
  </html>
  """

getDock = ->
  """
  <header id="main-header" class="kdview">
      <div class="inner-container">
          <a id="koding-logo" href="/">
              <cite></cite>
          </a>
          <div id="dock" class="">
              <div id="main-nav" class="kdview kdlistview kdlistview-navigation">
                  <a class="kdview kdlistitemview kdlistitemview-main-nav activity kddraggable running" href="/Activity" style="left: 0px;">
                      <span class="icon"></span>
                      <cite>Activity</cite>
                  </a>
                  <a class="kdview kdlistitemview kdlistitemview-main-nav teamwork kddraggable" href="/Teamwork" style="left: 55px;">
                      <span class="icon"></span>
                      <cite>Teamwork</cite>
                  </a>
                  <a class="kdview kdlistitemview kdlistitemview-main-nav terminal kddraggable" href="/Terminal" style="left: 110px;">
                      <span class="icon"></span>
                      <cite>Terminal</cite>
                  </a>
                  <a class="kdview kdlistitemview kdlistitemview-main-nav editor kddraggable" href="/Ace" style="left: 165px;">
                      <span class="icon"></span>
                      <cite>Editor</cite>
                  </a>
                  <a class="kdview kdlistitemview kdlistitemview-main-nav apps kddraggable" href="/Apps" style="left: 220px;">
                      <span class="icon"></span>
                      <cite>Apps</cite>
                  </a>
              </div>
          </div>
      </div>
  </header>
  """

putContent = (account, sUpdates)->
  getGraphMeta  = require './graphmeta'
  {profile:{nickname, firstName, lastName, about}} = account if account
  nickname or= "A koding nickname"
  firstName or= "a koding "
  lastName or= "user"
  about    or= ""

  numberOfLikes = if account.counts.likes then account.counts.likes else "0"
  numberOfFollowers = if account.counts.followers then account.counts.followers else "0"
  numberOfFollowing = if account.counts.following then account.counts.following else "0"
  imgURL = "https://gravatar.com/avatar/#{account.profile.hash}?size=90&amp;d=https%3A%2F%2Fapi.koding.com%2Fimages%2Fdefaultavatar%2Fdefault.avatar.90.png"

     # <a href="#{uri.address}">Koding</a><br />
     #  <figure itemscope itemtype="http://schema.org/Person" title="#{firstName} #{lastName}">
     #      <h2 itemprop="name">
     #        <a href="#{uri.address}/#!/#{nickname}">#{nickname}</a>
     #      </h2>
     #      <figcaption>
     #        <img src="#{imgURL}" itemprop="image"/> <br>
     #        <a href="#{uri.address}/#!/#{nickname}">
     #          <span itemprop="givenName">#{firstName}</span>
     #          <span itemprop="familyName">#{lastName}</span>
     #        </a>
     #        <br>
     #        <span itemprop="interactionCount">#{numberOfLikes} likes.</span>
     #      </figcaption>
     #   </figure>
     #   #{sUpdates}


  content  =
    """
    <div id="kdmaincontainer" class="kdview">
      #{getDock()}
      <section id="main-panel-wrapper" class="kdview">
        <div id="main-tab-view" class="kdview kdscrollview kdtabview">
          <div class="kdview kdtabpaneview content-display clearfix content-display-wrapper content-page active">
            <div class="kdview member content-display" style="min-height: 735px;">
              <div class="kdview profilearea clearfix">
                <div class="users-profile clearfix">
                  <span class="avatarview" href="/#{nickname}" style="width: 81px; height: 81px; background-size: 81px; background-image: none;">
                    <img class="" width="81" height="81" src="#{imgURL}" style="opacity: 1;">
                  </span>
                  <h3 class="full-name">
                    <span class="kdview kdcontenteditableview firstName">#{firstName}</span>
                    <span class="kdview kdcontenteditableview lastName">#{lastName}</span>
                  </h3>
                  <div class="kdview kdcontenteditableview bio">#{about}</div>
                  <div class="profilestats">
                    <a class="kdview" href="/#"><span>#{numberOfFollowers}</span>Followers</a>
                    <a class="kdview" href="/#"><span>#{numberOfFollowing}</span>Following</a>
                    <a class="kdview" href="/#"><span>#{numberOfLikes}</span>Likes</a>
                  </div>
                </div>
              </div>
              <div class="extra-wide">
                <div class="kdview kdtabview feeder-tabs">
                  <div class="kdview kdtabpaneview statuses clearfix active">
                    <div class="kdview kdlistview kdlistview-statuses activity-related">
                      <div class="kdview kdlistitemview kdlistitemview-activity">
                        #{sUpdates}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
    """

