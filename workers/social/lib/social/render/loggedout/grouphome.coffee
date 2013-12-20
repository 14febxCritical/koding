module.exports = (options, callback)->
  {argv} = require 'optimist'
  {uri} = require('koding-config-manager').load("main.#{argv.c}")

  getStyles    = require './../styleblock'
  fetchScripts = require './../scriptblock'
  getGraphMeta = require './../graphmeta'
  getSidebar   = require './sidebar'
  encoder      = require 'he'

  {
    account, slug, title, content, body,
    avatar, counts, policy, customize,
    bongoModels, client
  } = options

  if uri?.address and slug
    shareUrl = uri.address + "/" + slug
  shareUrl or= "https://koding.com"

  prepareHTML  = (scripts)->
    """
    <!DOCTYPE html>
    <html prefix="og: http://ogp.me/ns#">
    <head>
      <title>#{encoder.escape title}</title>
      #{getStyles()}
      #{getGraphMeta title: title, shareUrl: shareUrl, body: body}
    </head>
    <body class="group">

    <div class="kdview" id="kdmaincontainer">
      <div id="invite-recovery-notification-bar" class="invite-recovery-notification-bar hidden"></div>
      <header class="kdview" id='main-header'>
        <div class="kdview">
          <a class="group" id="koding-logo" href="#"><span></span>#{encoder.escape title}</a>
        </div>
      </header>
      <section class="kdview" id="main-panel-wrapper">
        #{getSidebar()}
        <div class="kdview full" id="content-panel">
          <div class="kdview kdscrollview kdtabview" id="main-tab-view">
            <div id='maintabpane-activity' class="kdview content-area-pane activity content-area-new-tab-pane clearfix kdtabpaneview active">
              <div id="content-page-activity" class="kdview content-page activity kdscrollview">
                <div class="kdview screenshots" id="home-group-header" >
                  <section id="home-group-body" class="kdview kdscrollview">
                    <div class="group-desc">#{encoder.escape body}</div>
                  </section>
                  <div class="home-links" id="group-home-links">
                    <div class='overlay'></div>
                    <a class="custom-link-view browse orange" href="#"><span class="icon"></span><span class="title">Learn more...</span></a><a class="custom-link-view join green" href="/#{slug}/Login"><span class="icon"></span><span class="title">Request an Invite</span></a><a class="custom-link-view register" href="/#{slug}/Register"><span class="icon"></span><span class="title">Register an account</span></a><a class="custom-link-view login" href="/#{slug}/Login"><span class="icon"></span><span class="title">Login</span></a>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>

    #{KONFIG.getConfigScriptTag {entryPoint: { slug : slug, type: "group"}, roles:['guest'], permissions:[]}}
    #{scripts}
    </body>
    </html>
    """

  fetchScripts {bongoModels, client}, (err, scripts)->
    callback null, prepareHTML scripts
