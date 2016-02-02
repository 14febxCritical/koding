kd = require 'kd.js'
CustomLinkView = require './customlinkview'
kookies        = require 'kookies'

module.exports = class TopNavigation extends kd.CustomHTMLView

  menu = [
    { title : 'Koding University', href : 'http://learn.koding.com',         name : 'about' }
    { title : 'Teams',             href : '/Teams',                          name : 'teams' }
    { title : 'Features',          href : 'https://www.koding.com/Features', name : 'features', attributes: target: '_blank' }
    { title : 'Sign In',           href : '/Login',                          name : 'buttonized white login',  attributes : testpath : 'login-link' }
    { title : 'Sign Up',           href : '/Register',                       name : 'buttonized green signup', attributes : testpath : 'signup-link' }
  ]

  constructor: (options = {}, data) ->

    options.tagName  or= 'nav'
    options.navItems or= menu

    super options, data

    @menu = {}

    {mainView} = kd.singletons
    mainView.on 'MainTabPaneShown', @bound 'setActiveItem'


  viewAppended: ->

    @createItem options  for options in @getOptions().navItems


  createItem: (options) ->

    options.cssClass = options.name.toLowerCase()

    @addSubView @menu[options.name] = new CustomLinkView options


  setActiveItem: (pane) ->

    @unsetActiveItems()

    {name} = pane

    @menu[name]?.setClass 'active'


  unsetActiveItems: ->

    item.unsetClass 'active'  for own name, item of @menu
