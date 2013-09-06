class NewDNSRecordFormView extends KDCustomHTMLView

  constructor:(options={}, data)->
    options.cssClass = "record-form-view"
    super options, data

    {domain} = @getData()

    @typeLabel        = new KDLabelView
      title : "Record Type"

    @hostLabel    = new KDLabelView
      title : "Host"

    @destinationLabel = new KDLabelView
      title : "Value"

    @ttlLabel         = new KDLabelView
      title : "TTL"

    @priorityLabel    = new KDLabelView
      cssClass : "hidden"
      title    : "Priority"

    @header = new KDCustomHTMLView
      tagName: "header"
      partial: domain.domainType

    @typeSelectBox    = new KDSelectBox
      selectOptions : [
        {title: "A", value: "A"}
        {title: "CNAME", value: "CNAME"}
        {title: "MX", value: "MX"}
        {title: "TXT", value: "TXT"}
        {title: "NS", value: "NS"}
        {title: "SRV", value: "SRV"}
        {title: "AAAA", value: "AAAA"}
      ]
      change:=>
        if @typeSelectBox.getValue() isnt "MX"
          @priorityLabel.hide()
          @priorityInput.hide()
        else
          @priorityLabel.show()
          @priorityInput.show()

    @hostInput        = new KDInputView
    @destinationInput = new KDInputView
    @ttlInput         = new KDInputView
    @priorityInput    = new KDInputView
      cssClass : "hidden"

    @addButton = new KDButtonView
      title    : "Add Record"
      callback : @bound "createNewRecord"

    @addRecordLabel  = new KDLabelView
      title : ""

  createNewRecord: ->
    {domain} = @getData()

    recordType = @typeSelectBox.getValue()
    host       = @hostInput.getValue()
    value      = @destinationInput.getValue()
    ttl        = @ttlInput.getValue()
    priority   = @priorityInput.getValue()

    recordObj = {recordType, host, value, ttl, priority}

    domain.createDNSRecord recordObj, (err, record)=>
      log record, err
      if record
        return new KDNotificationView {title: "Your record has been saved."}
        @emit "newRecordCreated", recordObj
      else
        return new KDNotificationView
          title: "You need to activate your FREE DNS Services before you can perform this action"

  viewAppended: JView::viewAppended

  pistachio:->
    """
      {{> @header}}
      <section class="clearfix">
        <div class="input-container record-type">
          {{> @typeLabel}}
          <div>{{> @typeSelectBox }}</div>
        </div>
        <div class="input-container">
          {{> @hostLabel}}
          {{> @hostInput }}
        </div>
        <div class="input-container">
          {{> @destinationLabel}}
          {{> @destinationInput }}
        </div>
        <div class="input-container priority">
          {{> @priorityLabel }}
          {{> @priorityInput }}
        </div>
        <div class="input-container">
          {{> @ttlLabel}}
          {{> @ttlInput }}
        </div>
        <div class="input-container add-record">
          {{> @addRecordLabel}}
          {{> @addButton }}
        </div>
      </section>
    """