helpers = require '../helpers/helpers.js'

activitySelector = '[testpath=activity-list] section:nth-of-type(1) [testpath=ActivityListItemView]:first-child'


module.exports =


  likePost: (browser) ->

    user = helpers.beginTest(browser)
    helpers.likePost(browser, user)
    browser.end()


  unlikePost: (browser) ->

    user        = helpers.beginTest(browser)
    selector    = activitySelector + ' [testpath=activity-like-link]'
    likeElement = activitySelector + ' .like-summary'

    helpers.likePost(browser, user)

    browser
      .pause                    5000 # required
      .waitForElementVisible    selector + '.liked:not(.count)', 25000
      .click                    selector + '.liked:not(.count)'
      .waitForElementNotVisible likeElement, 25000
      .end()


  likeComment: (browser) ->

    helpers.postComment(browser)

    commentSelector = activitySelector + ' .comment-container .kdlistitemview-comment:first-child'

    browser
      .waitForElementVisible    commentSelector, 25000
      .click                    commentSelector + ' [testpath=activity-like-link]'
      .pause  2000
      .waitForElementVisible    commentSelector + ' .liked:not(.count)', 25000 # Assertion
      .end()


  unlikeComment: (browser) ->

    helpers.postComment(browser)

    commentSelector     = activitySelector + ' .comment-container .kdlistitemview-comment:first-child'
    likeLinkSelector    = commentSelector + ' [testpath=activity-like-link]:not(.like-count)'
    afterLikeSelector   = likeLinkSelector + '.liked'
    afterUnlikeSelector = commentSelector + ' [testpath=activity-like-link]:not(.liked):first-child'

    browser
      .waitForElementVisible    commentSelector, 25000
      .waitForElementVisible    likeLinkSelector, 25000
      .click                    likeLinkSelector
      .pause                    8000 # wait for latency to make sure really liked on server
      .waitForElementVisible    afterLikeSelector, 25000
      .click                    afterLikeSelector
      .pause                    8000 # wait for latency to make sure really unliked on server
      .waitForElementVisible    afterUnlikeSelector, 25000
      .end()


  checkSharePopup: (browser) ->

    helpers.postActivity(browser)

    selector           = activitySelector + ' .activity-actions span.optional'
    sharePopupSelector = '.activity-share-popup'

    browser
      .waitForElementVisible  selector, 25000
      .click                  selector
      .waitForElementVisible  sharePopupSelector, 20000
      .waitForElementVisible  sharePopupSelector + ' input.share-input', 20000 # Assertion
      .end()
