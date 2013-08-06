class FirewallFilterListController extends KDListViewController

  constructor:(options={}, data)->
    options.itemClass       or= FirewallFilterListItemView
    options.noItemView      or= new EmptyFirewallFilterListItemView
    options.viewOptions     or=
      type      : 'env-list'
      tagName   : 'table'
      partial   :
        """
        <thead>
          <tr>
            <th>Filter Name</th>
            <th>Filter Match</th>
            <th>Actions</th>
          </tr>
        </thead>
        """

    super options, data

    @fetchFilters()

    listView = @getListView()
    # set the data so filter items know which domain to work on
    listView.setData(data)

    listView.on "newFilterCreated", @bound 'fetchFilters'

    listView.on "filterDeleted", (item)=>
      @removeItem item
      @fetchFilters()

  fetchFilters:->
    {domain} = @getData()

    KD.remote.api.JProxyFilter.fetchFiltersByContext (err, filters)=>
      if filters
        domain.fetchProxyRulesWithMatches (err, ruleList)=>
          return console.log err if err

          ruleMatches = Object.keys(ruleList)

          if ruleMatches.length > 0
            for filter in filters
              if filter.match in ruleMatches
                filter.ruleAction = ruleList[filter.match]

          @instantiateListItems filters


  refreshFilters:->
    @removeAllItems()
    @fetchFilters()

