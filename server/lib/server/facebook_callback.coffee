{
  renderOauthPopup
  saveOauthToSession
}          = require './helpers'
{facebook} = KONFIG
http       = require "https"
{decode}   = require "querystring"

module.exports = (req, res) ->
  access_token = null
  {clientId}   = req.cookies
  {code}       = req.query

  unless code
    renderOauthPopup res, {error:"No code", provider:"facebook"}
    return

  url  = "https://graph.facebook.com/oauth/access_token?"
  url += "client_id=#{facebook.clientId}&"
  url += "redirect_uri=#{facebook.redirectUri}&"
  url += "client_secret=#{facebook.clientSecret}&"
  url += "code=#{code}"

  # Get access token with code
  http.get url, (httpResp)->
    rawResp = ""
    httpResp.on "data", (chunk) -> rawResp += chunk
    httpResp.on "end", ->
      access_token = decode(rawResp).access_token
      if access_token
        options =
          host    : "graph.facebook.com"
          path    : "/me?access_token=#{access_token}"
          method  : "GET"
        r = http.request options, fetchUserInfo
        r.end()
      else
        console.log "facebook err, no access token", rawResp
        renderOauthPopup res, {error:"No access token", provider:"facebook"}

  # Get user info with access token
  fetchUserInfo = (userInfoResp) ->
    rawResp = ""
    userInfoResp.on "data", (chunk) -> rawResp += chunk
    userInfoResp.on "end", ->
      {id, username}            = JSON.parse rawResp
      facebookResp              = {username}
      facebookResp["token"]     = access_token
      facebookResp["foreignId"] = id

      saveOauthToSession facebookResp, clientId, "facebook", (err)->
        if err
          console.log "facebook err, saving to session", err
          renderOauthPopup res, {error:err, provider:"facebook"}
          return

        renderOauthPopup res, {error:null, provider:"facebook"}
