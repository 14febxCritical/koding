class HomeAppView extends JView

  constructor:(options = {}, data)->

    super options, data


    #Slider
    @slider       = new HomeSlider
      cssClass    : "home-slider"
      pages       :
        "You"       :
          cssClass  : "slider-page"
          domId     : "you-page"
          pistachio :
            """
              <div class="wrapper">
                <figure><img src="/images/homeslide/you.jpg"></figure>
                <h3>
                  <i></i> Koding for <span>You</span>
                </h3>
                <p>
                  You have great ideas.  You want to meet brilliant minds, and bring those ideas to life.  You want to start simple.  Maybe soon you'll have a 10 person team, commanding 100s of servers.
                </p>
                <p>
                  You want to learn Python, Java, C, Go, Nodejs, HTML, CSS or Javascript or any other. Community will help you along the way.
                </p>
              </div>
            """
        "Developers":
          cssClass  : "slider-page"
          domId     : "developers-page"
          pistachio :
            """
              <div class="wrapper">
                <figure><img src="/images/homeslide/developers.jpg"></figure>
                <h3>
                  <i></i> Koding for <span>Developers</span>
                </h3>
                <p>
                  You can have an amazing VM that is better than your laptop.  It's connected to internet 100x faster.  You can share it with anyone you wish. Clone git repos.  Test and iterate on your code without breaking your setup.
                </p>
                <p>
                  It's free. Koding is your new localhost, in the cloud.
                </p>
              </div>
            """
        "Education" :
          cssClass  : "slider-page"
          domId     : "education-page"
          pistachio :
            """
              <div class="wrapper">
                <figure><img src="/images/homeslide/education.jpg"></figure>
                <h3>
                  <i></i> Koding for <span>Education</span>
                </h3>
                <p>
                  Have a group where your students enjoy the resources you provide to them. Have it private, invite-only, let them share, collaborate and submit their assignments together.10 students, or 10,000. Just 1 or 100s of computers.
                </p>
                <p>
                  Koding is your new classroom.
                </p>
              </div>
            """
        "Business"  :
          cssClass  : "slider-page"
          domId     : "business-page"
          pistachio :
            """
              <div class="wrapper">
                <figure><img src="/images/homeslide/business.jpg"></figure>
                <h3>
                  <i></i> Koding for <span>Business</span>
                </h3>
                <p>
                  When you hire someone, let them be in your environment in 5 minutes, collaborating with others, contributing code without sharing ssh keys, passwords. Stop cc'ing your team, stop looking for emails.
                </p>
                <p>
                  Koding is your new workspace.
                </p>
              </div>
            """

    @priceBoxes = new KDCustomHTMLView
      cssClass      : "price-boxes"
      bind          : "mouseleave"
      mouseleave    : =>
        @additionalVmBox.setClass "mouseleave"
        @freeVmBox.setClass       "mouseleave"
        KD.utils.wait 500, =>
          @additionalVmBox.unsetClass "mouseleave"
          @freeVmBox.unsetClass "mouseleave"

    @priceBoxes.addSubView @freeVmBox = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "free"
      partial   : "<span>Your first VM</span>Free"

    @priceBoxes.addSubView @additionalVmBox = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "paid"
      partial   : "<span>Each additional VM</span>$5 / Month"

    @statusLink = new KDCustomHTMLView
      tagName   : "a"
      partial   : "Status"
      tooltip   :
        title   : "Coming soon"

    @apiLink = new KDCustomHTMLView
      tagName   : "a"
      partial   : "Api"
      tooltip   :
        title   : "Coming soon"


  _windowDidResize:->
    @unsetClass "extra-wide wide medium narrow extra-narrow"
    w = @getWidth()
    @setClass if w > 1500    then ""
    else if 1000 < w < 1500  then "extra-wide"
    else if 800  < w < 1000  then "wide"
    else if 600  < w < 800   then "medium"
    else if 480  < w < 600   then "narrow"
    else "extra-narrow"

  viewAppended:->
    super

    # account = KD.whoami()

    # @addSubView @featuredActivities = new FeaturedActivitiesContainer
    # @addSubView @footer = new KDCustomHTMLView tagName : 'footer'

    # @emit 'ready'

    # @utils.wait 500, => @_windowDidResize()
    # KD.getSingleton("contentPanel").on "transitionend", (event)=>
    #   event.stopPropagation()
    #   @_windowDidResize()  if $(event.target).is "#content-panel"

  pistachio:->
    """
    <section class="slider-section" id="slider-section">
      {{> @slider}}
    </section>
    <section class="pricing-section" id="pricing-section">
      <h3>Simple Pricing</h3>
      <h4>Try it and see if it's really as cool as we say</h4>
      {{> @priceBoxes}}
      <div class="pricing-details">
        <span><strong>Always on*</strong> $25 / Month</span>
        <span><strong>Extra RAM</strong> $10 / GB / Month</span><br>
        <span><strong>Extra Disk Space</strong> $1 / GB / Month</span>
        <span><strong>Firewall / Backend Builder</strong> $5 / Per VM / Month</span>
      </div>
      <span class="pricing-contact"><a href="mailto:hello@koding.com?Subject=Please%20tell%20me..." target="_top">Contact us</a> for Education and Business pricing</span>
    </section>
    <footer class="home-footer">
      <section>
        <div class="fl">
          <span>© 2013 Koding, Inc.</span>
          <a href="/tos.html" target="_blank">Terms</a>
          <a href="/privacy.html" target="_blank">Privacy</a>
        </div>
        <div class="fr">
          {{> @statusLink}}
          {{> @apiLink}}
          <a href="http://blog.koding.com" target='_blank'>Blog</a>
          <a href="#">About</a>
        </div>
      </section>
    </footer>
    """

class HomeSlider extends KDCustomHTMLView
  constructor:()->
    super
    @pages    = []
    @navItems = []

  createNav:->
    @addSubView @navContainer = new KDCustomHTMLView
      tagName       : "nav"
      cssClass      : "slider-nav"

    for page in @pages
      @navContainer.addSubView item = new SliderLink
        title       : page.getOption "navTitle"
        slider      : page.parent
      @navItems.push item
      @goToPage @navItems.first

  goToPage:(item)->
    for _item in @navItems
      _item.unsetClass "active" if item isnt _item
    item.setClass "active"

    index = @navItems.indexOf item

    if @activePage?
      @activePage.unsetClass "active"

    @pages[index].setClass "active"
    @activePage = @pages[index]


  createPages:->
    for title, page of @getOption "pages"
      @addSubView _page = new KDCustomHTMLView
        cssClass        : page.cssClass
        domId           : page.domId
        pistachio       : page.pistachio
        navTitle        : title

      @pages.push _page

  viewAppended:->
    @createPages()
    @createNav()
    @goToPage @navItems.first

class SliderLink extends CustomLinkView
  constructor:(options)->
    super

  click:->
    slider = @getOption "slider"
    slider.goToPage this








