{argv}                               = require 'optimist'
{uri}                                = require('koding-config-manager').load("main.#{argv.c}")
{ daisy }                            = require "bongo"
{ Relationship }                     = require 'jraphical'
{ createActivityContent, decorateComment } = require '../helpers'

ITEMSPERPAGE = 20

module.exports = (bongo, page, contentType, callback)=>
  {JName, JAccount, JNewStatusUpdate, JTag} = bongo.models
  skip = 0
  if page > 0
    skip = (page - 1) * ITEMSPERPAGE


  options = {
    limit : ITEMSPERPAGE
    skip  : skip
    sort: 'meta.createdAt': -1
  }

  if contentType is "Activity"
    model = JNewStatusUpdate
  else if contentType is "Topics"
    model = JTag
  else
    return callback new Error "Unknown content type.", null

  pageContent = ""
  model.count {}, (error, count)=>
    return callback error, null  if error
    return callback null, null  if count is 0
    model.some {}, options, (err, contents)=>
      return callback err, null  if err
      return callback null, null  if contents.length is 0
      queue = [0..contents.length - 1].map (index)=>=>
        queue.pageContent or= ""

        content = contents[index]

        if contentType is "Activity"
          createFullHTML = no
          putBody = yes
          createActivityContent JAccount, content, {}, createFullHTML, putBody, (error, content)=>
            return queue.next()  if error or not content
            queue.pageContent = queue.pageContent + content
            queue.next()
        else if contentType is "Topics"
          appendDecoratedTopic content, queue
        else queue.next()
      queue.push =>
        schemaorgTagsOpening = getSchemaOpeningTags contentType
        schemaorgTagsClosing = getSchemaClosingTags contentType

        # content = schemaorgTagsOpening + queue.pageContent + schemaorgTagsClosing
        content = queue.pageContent

        pagination = getPagination page, count, contentType
        fullPage = putContentIntoFullPage content, pagination, contentType
        return callback null, fullPage
      daisy queue

getPagination = (currentPage, numberOfItems, contentType)->
  # This is the number of adjacent link around current page.
  # E.g. let current page be 9, then pagination will look like this:
  # First Prev ... 4 5 6 7 8 9 10 11 12 13 14 ... Next Last
  # (Except 3-dots, they are useless for bots.)
  PAGERWINDOW = 5

  numberOfPages = Math.ceil(numberOfItems / ITEMSPERPAGE)
  firstLink = prevLink = nextLink = lastLink = ""

  if currentPage > 1
    firstLink = getSinglePageLink 1, contentType, "First"
    prevLink  = getSinglePageLink (currentPage - 1), contentType, "Previous"

  if currentPage < numberOfPages
    lastLink  = getSinglePageLink numberOfPages, contentType, "Last"
    nextLink  = getSinglePageLink (currentPage + 1), contentType, "Next"

  pagination = firstLink + prevLink

  start = 1
  end = numberOfPages

  start = currentPage - PAGERWINDOW  if currentPage > PAGERWINDOW

  if currentPage + PAGERWINDOW < numberOfPages
    end   = currentPage + PAGERWINDOW

  [start..end].map (pageNumber)=>
    pagination += getSinglePageLink pageNumber, contentType

  pagination += nextLink
  pagination += lastLink

  return pagination


getSinglePageLink = (pageNumber, contentType, linkText=pageNumber)->
  # link = "<a href='#{uri.address}/#!/Activity/&page=#{pageNumber}'>#{linkText}  </a>"
  link = "<a href='#{uri.address}/#!/#{contentType}?page=#{pageNumber}'>#{linkText}  </a>"
  return link

appendDecoratedTopic = (tag, queue)=>
  queue.pageContent += createTagNode tag
  queue.next()

getSchemaOpeningTags = (contentType)=>
  openingTags = ""
  if contentType is "Activity"
    openingTags =
      """
        <article itemscope itemtype="http://schema.org/BlogPosting">
          <div itemscope itemtype="http://schema.org/ItemList">
            <meta itemprop="mainContentOfPage" content="true"/>
            <h2 itemprop="name">Latest activities</h2><br>
            <meta itemprop="itemListOrder" content="Descending" />
      """
  else if contentType is "Topics"
    openingTags =
      """
        <div itemscope itemtype="http://schema.org/ItemList">
          <meta itemprop="mainContentOfPage" content="true"/>
          <h2 itemprop="name">Latest topics</h2><br>
          <meta itemprop="itemListOrder" content="Descending" />
      """
  return openingTags

getSchemaClosingTags = (contentType)=>
  closingTags = ""
  if contentType is "Activity"
    closingTags = "</div></article>"
  else if contentType is "Topics"
    closingTags = "</div>"
  return closingTags

createTagNode = (tag)->
  tagContent = ""
  return tagContent  unless tag.title
  """
  <div class="kdview kdlistitemview kdlistitemview-topics topic-item">
    <header>
      <h3 class="subview">
        <a href="#{uri.address}/#!/Activity?tagged=#{tag.slug}">
          <span itemprop="itemListElement">#{tag.title}</span>
        </a>
      </h3>
    </header>
    <div class="stats">
      <a href="#"><span>#{tag.counts?.post ? 0}</span></a>Posts
      <a href="#"><span>#{tag.counts?.followers ? 0}</span></a>Followers
    </div>
    <article>#{tag.body ? ''}</article>
  </div>
  """

createFollowersCount = (numberOfFollowers)->
  return "<span>#{numberOfFollowers}</span> followers"

createUserInteractionMeta = (numberOfFollowers)->
  userInteractionMeta = "<meta itemprop=\"interactionCount\" content=\"UserComments:#{numberOfFollowers}\"/>"
  return userInteractionMeta

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

putContentIntoFullPage = (content, pagination, contentType)->
  getGraphMeta  = require './graphmeta'

  """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <title>Koding</title>
      #{getGraphMeta()}
    </head>
    <body itemscope itemtype="http://schema.org/WebPage" class="super activity">
      <div id="kdmaincontainer" class="kdview">
        #{getDock()}
        <section id="main-panel-wrapper" class="kdview">
          <div id="main-tab-view" class="kdview kdscrollview kdtabview">
            <div class="kdview kdtabpaneview activity clearfix content-area-pane active">

              <div id="content-page-#{contentType.toLowerCase()}" class="kdview kdscrollview content-page #{contentType.toLowerCase()} loggedin">
                <main class="">
                  <div class="kdview activity-content feeder-tabs">
                    <div class="kdview listview-wrapper">
                      <div class="kdview kdscrollview">
                        <div class="kdview kdlistview kdlistview-default activity-related">
                          <div></div>
                          #{content}
                        </div>
                      </div>
                    </div>
                    <nav class="crawler-pagination clearfix">
                      #{pagination}
                    </div>
                  </div>
                </main>
              </div>
            </div>
          </div>
        </section>
      </div>
    </body>
    </html>
  """
