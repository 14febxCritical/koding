class PermissionsGrid extends KDView

  viewAppended:->
    @setPartial @partial()

  ['list','reducedList','tree'].forEach (method)=>
    @::[method] =-> @getPermissions method

  getPermissions:(structure='reducedList')->
    values = @$('form')
      .serializeArray()
      .map ({name})->
        [facet, role, permission] = name.split '|'
        module = facet.split('-')[1]
        {
          module
          role
          permission
        }
    switch structure
      when 'list' then return values
      when 'tree'
        values.reduce (acc, {module, role, permission})->
          acc[module] ?= {}
          acc[module][role] ?= []
          acc[module][role].push permission
          return acc
        , {}
      when 'reducedList'
        cache = {}
        values.reduce (acc, {module, role, permission})->
          storageKey = module+':'+role
          cached = cache[storageKey]
          if cached?
            cached.permissions.push permission
          else
            cache[storageKey] = {module, role, permissions: [permission]}
            acc.push cache[storageKey]
          return acc
        , []
      else throw new Error "Unknown structure #{structure}"

  _getCheckbox =(module, permission, role)->
    name = ['permission', module].join('-')+'|'+[role, permission].join('|')
    """
    <input type=checkbox name='#{name}'#{
      if role is 'admin' then ' disabled checked' else ''
    }>
    """

  partial:->
    {permissionSet, privacy} = @getOptions()
    partial = """
    <form><table class="permissions-grid">
      <thead><tr>
        <th></th>
        #{if privacy is 'public' then '<th>guest</th>' else ''}
        <th>member</th><th>moderator</th><th>admin</th>
      </tr></thead>
      <tbody>
    """
    for own module, permissions of permissionSet.permissionsByModule
      partial += """
      <tr>
        <td class="module" colspan=#{
          if privacy is 'public' then '5' else '4'
        }><strong>#{module}</strong></td>
      </tr>
      """
      for permission in permissions
        partial += """
        <tr>
          <td class="permission">#{permission}</td>
          #{if privacy is 'public' then "<td>#{
            _getCheckbox module, permission, 'guest'
          }</td>" else ''}
          <td>#{_getCheckbox module, permission, 'member'}</td>
          <td>#{_getCheckbox module, permission, 'moderator'}</td>
          <td>#{_getCheckbox module, permission, 'admin'}</td>
        </tr>
        """
    partial += """
      </tbody>
    </table></form>
    """
    partial