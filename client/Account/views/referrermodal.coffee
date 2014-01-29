class ReferrerModal extends KDModalView

  constructor: (options = {}, data) ->

    options.domId    = "terabyte-campaign-modal"
    options.overlay  = yes
    options.width    = 780

    super options, data

    @addSubView new ReferrerModalContent


class ReferrerModalContent extends JView

  constructor: (options = {}, data) ->

    options.cssClass = "referrer-modal"

    super options, data

    url = KD.getReferralUrl KD.nick()

    @urlInput      = new KDInputView
      defaultValue : url
      cssClass     : "share-url-input"
      attributes   : readonly : "true"
      click        : -> @selectAll()

    @twitter  = new TwitterShareLink  { url , trackingName: "referrer" }
    @facebook = new FacebookShareLink { url , trackingName: "referrer" }
    @linkedin = new LinkedInShareLink { url , trackingName: "referrer" }

  pistachio: ->
    """
      <div class="left">
        <div class="logo"></div>
      </div>
      <div class="right">
        <div class="content">
          <div class="title">
            <span class="icon"></span>
            <span>#Crazy100TBWeek</span>
          </div>
          <p class="content-text">
            Only this week, share your link,
            they get <strong>5GB</strong> instead of 4GB,
            and you get <strong>1GB extra</strong>!
          </p>
          {{> @urlInput}}
          <div class="share-links">
            {{> @twitter}}
            {{> @facebook}}
            {{> @linkedin}}
          </div>
        </div>
      </div>
    """
