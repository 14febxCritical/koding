class DomainCreationForm extends KDTabViewWithForms

  domainNameValidation =
    rules      :
      required : yes
      regExp   : /^([\da-z\.-]+)\.([a-z\.]{2,6})$/i
    messages   :
      required : "Enter your domain name"
      regExp   : "This doesn't look like a valid domain name."

  constructor:->

    {nickname, firstName, lastName} = KD.whoami().profile

    paymentController = KD.getSingleton('paymentController')
    group             = KD.getSingleton("groupsController").getCurrentGroup()
    domainOptions     = [
      { title : "Create a subdomain",                                      value : "subdomain" }
      { title : "I want to register a domain <cite>coming soon...</cite>", value : "new" }
      { title : "I already have a domain <cite>coming soon...</cite>",     value : "existing" }
    ]

    super
      navigable                       : no
      goToNextFormOnSubmit            : no
      hideHandleContainer             : yes
      forms                           :
        "Domain Address"              :
          callback                    : @bound "registerDomain"
          buttons                     :
            billingButton             :
              title                   : "Billing Info"
              style                   : "cupid-green hidden"
              type                    : "submit"
              loader                  :
                color                 : "#ffffff"
                diameter              : 24
              callback                : =>
                form = @forms["Domain Address"]
                {createButton, billingButton} = form.buttons

                billingButton.hideLoader()

                paymentController.setBillingInfo 'user', group, (success)->
                  if success
                    billingButton.hide()
                    createButton.show()

            createButton              :
              title                   : "Add Domain"
              style                   : "cupid-green"
              type                    : "submit"
              loader                  :
                color                 : "#ffffff"
                diameter              : 24
            close                     :
              title                   : "Back to settings"
              style                   : "cupid-green hidden"
              callback                : => @reset()
            cancel                    :
              style                   : "modal-cancel"
              callback                : => @emit 'DomainCreationCancelled'
            another                   :
              title                   : "add another domain"
              style                   : "modal-cancel hidden"
              callback                : => @addAnotherDomainClicked()
          fields                      :
            header                    :
              title                   : "Add a domain"
              itemClass               : KDHeaderView
            DomainOption              :
              name                    : "DomainOption"
              itemClass               : KDRadioGroup
              cssClass                : "group-type"
              defaultValue            : "subdomain"
              radios                  : domainOptions
              change                  : =>
                {DomainOption, domainName, domains, regYears} = @forms["Domain Address"].inputs
                actionState = DomainOption.getValue()
                domainName.getElement().setAttribute 'placeholder', switch actionState
                  when "new"
                    @suggestionBox?.show()
                    # domainName.setValidation domainNameValidation
                    domains.hide()
                    regYears.show()
                    @needBilling yes
                    "#{KD.utils.slugify firstName}s-new-domain.com"
                  when "existing"
                    @suggestionBox?.hide()
                    # domainName.setValidation domainNameValidation
                    domains.hide()
                    regYears.hide()
                    @needBilling no
                    "#{KD.utils.slugify firstName}s-existing-domain.com"
                  when "subdomain"
                    # domainName.unsetValidation()
                    @suggestionBox?.hide()
                    domains.show()
                    regYears.hide()
                    @needBilling no
                    "#{KD.utils.slugify firstName}s-subdomain"
            domainName                :
              cssClass                : "domain"
              placeholder             : "#{KD.utils.slugify firstName}s-subdomain"
              validate                :
                rules                 :
                  required            : yes
                messages              :
                  required            : "Subdomain name is required!"
              nextElement             :
                regYears              :
                  cssClass            : "hidden"
                  itemClass           : KDSelectBox
                  selectOptions       : ({title: "#{i} Year#{if i > 1 then 's' else ''}", value:i} for i in [1..10])
                domains               :
                  cssClass            : "domains"
                  itemClass           : KDSelectBox
                  validate            :
                    rules             :
                      required        : yes
                    messages          :
                      required        : "Please select a parent domain."
            suggestionBox             :
              type                    : "hidden"

    form = @forms["Domain Address"]
    {createButton} = form.buttons

    form.on "FormValidationFailed", createButton.bound 'hideLoader'
    @on "DomainCreationCancelled", createButton.bound 'hideLoader'

  viewAppended:->
    KD.whoami().fetchDomains (err, userDomains)=>
      warn err  if err
      domainList = []
      for domain in userDomains
        if not domain.regYears > 0
          domainList.push {title:".#{domain.domain}", value:domain.domain}
      @forms["Domain Address"].inputs.domains.setSelectOptions domainList

  needBilling:(paymentRequired)->
    form = @forms["Domain Address"]
    {createButton, billingButton} = form.buttons

    unless paymentRequired
      createButton.show()
      billingButton.hide()
      return

    paymentController = KD.getSingleton('paymentController')
    group             = KD.getSingleton("groupsController").getCurrentGroup()

    paymentController.getBillingInfo 'user', group, (err, account)->
      need = err or not account or not account.cardNumber
      if need
        billingButton.show()
        createButton.hide()
      else
        createButton.show()
        billingButton.hide()

  registerDomain:->
    form = @forms["Domain Address"]
    {createButton} = form.buttons
    @clearSuggestions()

    {DomainOption, domainName, regYears, domains} = form.inputs
    splittedDomain    = domainName.getValue().split "."
    domain            = splittedDomain.first
    tld               = splittedDomain.slice(1).join('')
    domainInput       = domainName
    domainName        = domainInput.getValue()

    domainOptionValue = DomainOption.getValue()

    if domainOptionValue is 'new'
      KD.remote.api.JDomain.isDomainAvailable domain, tld, (avErr, status, suggestions)=>

        if avErr
          createButton.hideLoader()
          log domain
          log tld
          log avErr
          return notifyUser "An error occured: #{avErr}"

        switch status
          when "regthroughus", "regthroughothers"
            @showSuggestions suggestions
            return createButton.hideLoader()
          when "unknown"
            notifyUser "An error occured. Please try again later."
            return createButton.hideLoader()

        KD.remote.api.JDomain.registerDomain
          domainName : domainInput.getValue()
          years      : regYears.getValue()
        , (err, domain)=>
          createButton.hideLoader()
          if err
            warn err
            notifyUser "An error occured. Please try again later."
          else
            @showSuccess domain
            domain.setDomainCNameToProxyDomain()

    else if domainOptionValue is 'existing'
      @createDomain {domainName, regYears:0}, (err, domain)=>
        createButton.hideLoader()
        if err
          warn err
          if err.message?.indexOf("duplicate key error") isnt -1
            return notifyUser "The domain #{domainName} already exists."
          return notifyUser "Invalid domain #{domainName}.  "
        else
          @showSuccess domain

    else # create a subdomain
      subDomainPattern = /^([a-z0-9]([_\-](?![_\-])|[a-z0-9]){0,60}[a-z0-9]|[a-z0-9])$/
      unless subDomainPattern.test domainName
        createButton.hideLoader()
        return notifyUser "#{domainName} is an invalid subdomain."
      domainName = "#{domainName}.#{domains.getValue()}"

      @createDomain {domainName, regYears:0}, (err, domain)=>
        createButton.hideLoader()
        if err
          warn err
          if err.message?.indexOf("duplicate key error") isnt -1
            return notifyUser "The domain #{domainName} already exists."
          return notifyUser "An error occured. Please try again later."
        else
          @showSuccess domain

  createDomain:(params, callback)->
    KD.remote.api.JDomain.createDomain
        domain         : params.domainName
        regYears       : params.regYears
        proxy          : { mode: 'vm' }
        hostnameAlias  : []
        loadBalancer   :
            mode       : "roundrobin"
      , (err, domain)=>
        callback err, domain

  clearSuggestions:-> @suggestionBox?.destroy()

  showSuggestions:(suggestions)->
    @clearSuggestions()

    form            = @forms["Domain Address"]
    {domainName}    = form.inputs
    {suggestionBox} = form.fields
    partial         = "<p>This domain is already registered. You may click and try one below.</p>"

    for domain, variants of suggestions
      for variant, status of variants when status is "available"
        partial += "<li class='#{variant}'>#{domain}.#{variant}</li>"

    suggestionBox.addSubView @suggestionBox = new KDCustomHTMLView
      tagName : 'ul'
      cssClass: 'suggestion-box'
      partial : partial
      click   : (event)->
        domainName.setValue $(event.target).closest('li').text()

  showSuccess:(domain)->
    @clearSuggestions()
    form            = @forms["Domain Address"]
    {domainName}    = form.inputs
    {suggestionBox} = form.fields
    {close, createButton, cancel, another} = form.buttons

    close.show()
    another.show()
    createButton.hide()
    cancel.hide()

    @emit 'DomainSaved', domain

    suggestionBox.addSubView @successNote = new KDCustomHTMLView
      tagName : 'p'
      cssClass: 'success'
      # the following partial will vary depending on the DomainOption value.
      # Users who registered a domain through us won't need this change.
      # partial : "<b>Thank you!</b><br>Your domain #{domainName.getValue()} has been added to our database. Please go to your provider's website and add a CNAME record mapping to kontrol.in.koding.com."

      # change this part when registering is there.
      partial : "<b>Thank you!</b><br>Your subdomain <strong>#{domainName.getValue()}</strong> has been added to our database. You can dismiss this panel and point your new domain to one of your VMs on the settings screen."
      click   : => @reset()


  reset:->
    form            = @forms["Domain Address"]
    {domainName}    = form.inputs
    {suggestionBox} = form.fields
    {close, createButton, cancel, another} = form.buttons

    close.hide()
    another.hide()
    createButton.show()
    cancel.show()
    @successNote.destroy()
    delete @successNote
    domainName.setValue ''
    @emit 'CloseClicked'

  addAnotherDomainClicked:->
    form            = @forms["Domain Address"]
    {domainName}    = form.inputs
    {suggestionBox} = form.fields
    {close, createButton, cancel, another} = form.buttons

    close.hide()
    another.hide()
    createButton.show()
    cancel.show()
    @successNote.destroy()
    delete @successNote
    domainName.setValue ''
    domainName.setFocus()

  notifyUser = (msg)->
    new KDNotificationView
      type     : 'tray'
      title    : msg
      duration : 5000