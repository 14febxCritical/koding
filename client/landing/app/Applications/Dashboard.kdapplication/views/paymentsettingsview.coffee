class GroupPaymentSettingsView extends JView

  constructor:->
    super
    @setClass "paymment-settings-view group-admin-modal"
    group = @getData()

    formOptions =
      callback: (formData) =>
        { Save: saveButton } = @settingsForm.buttons

        if formData['allow-over-usage']
          if formData['require-approval']
            overagePolicy = 'by permission'
          else
            overagePolicy = 'allowed'
        else
          overagePolicy = 'not allowed'

        # TODO: Delete shared VM if it's disabled?

        updateOptions = 
          overagePolicy : overagePolicy
          sharedVM      : formData['shared-vm']
          allocation    : formData.allocation

        group.updateBundle updateOptions, -> saveButton.hideLoader()

      buttons:
        Save                :
          style             : "modal-clean-green"
          type              : "submit"
          loader            :
            color           : "#444444"
            diameter        : 12
      fields                :
        billing             :
          label             : "Billing Method"
          itemClass         : BillingMethodView
        history             :
          label             : "Payment History"
          tagName           : "a"
          partial           : "Show Payment History"
          itemClass         : KDCustomHTMLView
          cssClass          : "billing-link"
          click             : =>
            new GroupPaymentHistoryModal {group}
        subscriptions       :
          label             : "Subscriptions"
          tagName           : "a"
          partial           : "Show Subscriptions"
          itemClass         : KDCustomHTMLView
          cssClass          : "billing-link"
          click             : =>
            new GroupSubscriptionsModal {group}
        expensedVMs         :
          label             : "User VMs"
          tagName           : "a"
          partial           : "Show User VMs"
          itemClass         : KDCustomHTMLView
          cssClass          : "billing-link"
          click             : =>
            new GroupVMsModal {group}
        sharedVM            :
          label             : "Shared VM"
          itemClass         : KDOnOffSwitch
          name              : "shared-vm"
          cssClass          : "hidden"
        vmDesc              :
          itemClass         : KDCustomHTMLView
          cssClass          : "vm-description hidden"
          partial           : """<section>
                                <p>If you enable this, your group will have a shared VM.</p>
                              </section>"""
        allocation          :
          itemClass         : KDSelectBox
          label             : "Resources"
          type              : "select"
          name              : "allocation"
          defaultValue      : "0"
          selectOptions     : [
            { title : "None",  value : "0" }
            { title : "$ 10",  value : "1000" }
            { title : "$ 20",  value : "2000" }
            { title : "$ 30",  value : "3000" }
            { title : "$ 50",  value : "5000" }
            { title : "$ 100", value : "10000" }
          ]
        allocDesc           :
          itemClass         : KDCustomHTMLView
          cssClass          : "alloc-description"
          partial           : """<section>
                                <p>You can pay for your members' resources. Each member's 
                                payment up to a specific amount will be charged from your 
                                balance.</p>
                              </section>"""
        overagePolicy       :
          label             : "Over-usage"
          itemClass         : KDOnOffSwitch
          name              : "allow-over-usage"
          cssClass          : "no-title"
          callback          : (state)=>
            if state
              @settingsForm.fields.approval.show()
            else
              @settingsForm.fields.approval.hide()
        approval            :
          label             : "Need Approval"
          itemClass         : KDOnOffSwitch
          name              : "require-approval"
          cssClass          : "no-title"

    @settingsForm = new KDFormViewWithFields formOptions, group

    @forwardEvent @settingsForm.inputs.billing, 'BillingEditRequested'

    group.fetchBundle (err, bundle)=>
      if err or not bundle
        return

      { fields, inputs } = @settingsForm
        
      if bundle.allocation
        inputs.allocation.setValue bundle.allocation

      if bundle.sharedVM
        inputs.sharedVM.setOn()

      fields.approval.hide()
      
      if bundle.overagePolicy is "by permission"
        inputs.overagePolicy.setOn()
        inputs.approval.setOn()
        fields.approval.show()

      else if bundle.overagePolicy is "allowed"
        inputs.overagePolicy.setOn()
        fields.approval.show()

  setBillingInfo: (billingInfo) ->
    { billing: billingView } = @settingsForm.inputs
    billingView.setBillingInfo billingInfo

  pistachio:-> "{{> @settingsForm}}"