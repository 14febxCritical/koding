class VmProductForm extends FormWorkflow

  createUpgradeForm: ->
    (KD.getSingleton 'paymentController').createUpgradeForm 'vm', yes

  checkUsageLimits: (pack, plan, callback) ->
    [callback, plan] = [plan, callback]  unless callback

    data = @getData()

    { subscription, oldSubscription } = data

    plan ?= data.plan

    if subscription
      subscription.checkUsage pack, (err, usage) =>
        if err
          @collectData oldSubscription: subscription
          @clearData 'subscription'

        callback err, usage
    else if plan
      usage = oldSubscription?.quantities ? {}
      spend = pack.quantities

      plan.checkQuota {usage, spend, multiplyFactor: 1}, (err, usage) =>
        if err
          @clearData 'plan'

        callback err, usage

  createPackChoiceForm: -> new PackChoiceForm
    title     : 'Choose your VM'
    itemClass : VmProductView

  setCurrentSubscriptions: (subscriptions) ->
    @currentSubscriptions = subscriptions
    switch subscriptions.length
      when 0
        @showForm 'upgrade'
      when 1
        [subscription] = subscriptions
        @collectData { subscription }
      else
        [subscription] = subscriptions
        @collectData { subscription }
        console.warn { message: 'User has multiple subscriptions', subscriptions }
        # @showForm 'choice'

  setContents: (type, contents) -> switch type
    when 'packs'
      (@getForm 'pack choice').setContents contents

  createChoiceForm: -> new KDView partial: 'this is a plan choice form'

  prepareWorkflow: ->

    { all, any } = Junction

    @requireData all(

      any('subscription', 'plan')

      'pack'
    )

    upgradeForm = @createUpgradeForm()
    upgradeForm.on 'PlanSelected', (plan) =>
      { pack } = @collector.data

      if pack
        @checkUsageLimits pack, plan, (err) =>
          return  if KD.showError err

          @collectData { plan }
      else
        @collectData { plan }

    @addForm 'upgrade', upgradeForm, ['plan', 'subscription']

    packChoiceForm = @createPackChoiceForm()
    packChoiceForm.once 'Activated', => @emit 'PackOfferingRequested'

    packChoiceForm.on 'PackSelected', (pack) =>
      @checkUsageLimits pack, (err) =>
        KD.showError err # don't return

        @collectData { pack }

    @addForm 'pack choice', packChoiceForm, ['pack']

    choiceForm = @createChoiceForm()
