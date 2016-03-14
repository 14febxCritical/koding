utils    = require '../utils/utils.js'
helpers  = require '../helpers/helpers.js'


module.exports =

  loginWithUsername: (browser) ->

    helpers.beginTest(browser)

    browser.end()


  loginWithEmail: (browser) ->

    ourUser = utils.getUser()

    user = {
      username: ourUser.email
      password: ourUser.password
      email   : ourUser.email
    }

    helpers.beginTest(browser, user)
    browser.end()


  loginWithInvalidUsername: (browser) ->

    user = {
      username: 'r2d2'
      password: 'WEEyoh'
    }

    helpers.assertNotLoggedIn(browser, user)
    browser.end()


  loginWithInvalidPassword: (browser) ->

    ourUser = utils.getUser()
    user    = {
      username: ourUser.username
      password: '12312312'
    }

    helpers.assertNotLoggedIn(browser, user)
    browser.end()


  loginFromSignupModal: (browser) ->

    user = utils.getUser()
    url  = helpers.getUrl()
    url  = "#{url}/RegisterForTests"

    browser
      .url(url)
      .maximizeWindow()

    browser
      .waitForElementVisible  '[testpath=login-container]', 50000
      .setValue               '.main-part [testpath=register-form-email]', user.email
      .setValue               '.main-part input[name=password]', user.password
      .click                  '.main-part [testpath=signup-button]'
      .waitForElementVisible  '[testpath=main-sidebar]', 10000 # Assertion
      .end()
