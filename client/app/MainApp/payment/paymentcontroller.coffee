class PaymentController extends KDController

  getGroup = ->
    KD.getSingleton('groupsController').getCurrentGroup()

  getBalance: (type, callback)->
    
    { JRecurlyPlan } = KD.remote.api

    if type is 'user'
      JRecurlyPlan.getUserBalance callback
    else
      JRecurlyPlan.getGroupBalance callback

  updateCreditCard: (type, callback = (->)) ->

    { JRecurlyPlan } = KD.remote.api

    @updateCreditCardModal {}, (newData) =>
      @modal.buttons.Save.hideLoader()
      if type in ['group', 'expensed']
        getGroup().setBillingInfo newData, callback
      else
        JRecurlyPlan.setUserAccount newData, callback

  fetchBillingInfo: (type, callback) ->
    
    { JRecurlyPlan } = KD.remote.api

    if type in ['group', 'expensed']
      getGroup().fetchBillingInfo callback
    else
      JRecurlyPlan.getAccount callback

  getSubscription: do ->
    findActiveSubscription = (subs, planCode, callback) ->
      subs.reverse().forEach (sub) ->
        if sub.planCode is planCode and sub.status in ['canceled', 'active']
          return callback sub

      callback 'none'

    getSubscription = (type, planCode, callback) ->
      { JRecurlySubscription } = KD.remote.api

      if type is 'group'
        getGroup().checkPayment (err, subs) =>
          findActiveSubscription subs, planCode, callback
      else
        JRecurlySubscription.getUserSubscriptions (err, subs) ->
          findActiveSubscription subs, planCode, callback

  confirmPayment: (type, plan, callback = (->)) ->
    getGroup().canCreateVM { type, planCode: plan.code }, (err, status) =>
      @getSubscription type, plan.code, (subscription) =>
        cb = (needBilling, balance, amount) =>
          @createPaymentConfirmationModal {
            needBilling, balance, amount, type, group, plan, subscription
          }, callback

        if status
          cb no, 0, 0
        else
          @fetchBillingInfo type, group, (err, billing) =>
            needBilling = err or not billing?.cardNumber?

            @getBalance type, group, (err, balance) =>
              balance = 0  if err
              cb needBilling, balance, plan.feeMonthly

  makePayment: (type, plan, amount) ->
    vmController = KD.getSingleton('vmController')

    if amount is 0
      vmController.createGroupVM type, plan.code
    else if type in ['group', 'expensed']
      paymentInfo = { plan: plan.code, multiple: yes }
      getGroup().makePayment paymentInfo, (err, result)->
        return KD.showError err  if err
        vmController.createGroupVM type, plan.code
    else
      plan.subscribe multiple: yes, (err, result)->
        return KD.showError err  if err
        vmController.createGroupVM type, plan.code

  deleteVM: (vmInfo, callback) ->
    type  =
      if (vmInfo.planOwner.indexOf 'user_') > -1 then 'user'
      else if vmInfo.type is 'expensed'          then 'expensed'
      else 'group'

    @getSubscription getGroup(), type, vmInfo.planCode,\
      @createDeleteConfirmationModal.bind this, type, callback

  # views

  updateCreditCardModal: (data, callback) ->
    @modal = new PaymentFormModal { callback }

    form = @modal.modalTabs.forms['Billing Info']
    form.inputs[k]?.setValue v  for k, v of data

    @modal.on 'KDObjectWillBeDestroyed', => delete @modal
    return @modal

  fetchBillingInfo: (type, callback) ->
    
    { JRecurlyPlan } = KD.remote.api

    switch type
      when 'group'
        debugger
      when 'user'
        JRecurlyPlan.getAccount callback

  updateBillingInfo: (billingInfo, callback) ->
    
    { JRecurlyPlan } = KD.remote.api

    JRecurlyPlan.setUserAccount newData, (err, result)->
      debugger


  createBillingInfoModal:(type, billingInfo) ->

    modal = new BillingFormModal { type }, billingInfo

    @fetchCountryData (err, countries, countryOfIp) =>
      modal.setCountryData { countries, countryOfIp }

    return modal

  fetchCountryData:(callback)->

    { JRecurly } = KD.remote.api

    if @countries or @countryOfIp
      return @utils.defer => callback null, @countries, @countryOfIp

    ip = $.cookie 'clientIPAddress'
    
    JRecurly.fetchCountryDataByIp ip, (err, @countries, @countryOfIp) =>
      callback err, @countries, @countryOfIp

  createPaymentConfirmationModal: (options, callback)->
    options.callback or= callback
    return new PaymentConfirmationModal options

  createDeleteConfirmationModal: (type, callback, subscription)->
    return new PaymentDeleteConfirmationModal { subscription, type, callback }
