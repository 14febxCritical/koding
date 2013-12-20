class NavigationList extends KDListView

  constructor:->
    super

    @viewWidth = 55

    @on 'ItemWasAdded', (view)=>

      view.once 'viewAppended', =>

        view._index ?= @getItemIndex view
        view.setX view._index * @viewWidth
        @_width = @viewWidth * (@items.length + 1)

      lastChange = 0

      view.on 'DragInAction', (x, y)=>

        if view.data.type isnt 'persistent' and y > 125
        then view.setClass 'remove'
        else view.unsetClass 'remove'

        return  if x + view._x > @_width or x + view._x < 0

        if x > @viewWidth
          current = Math.floor x / @viewWidth
        else if x < -@viewWidth
          current = Math.ceil  x / @viewWidth
        else
          current = 0

        if current > lastChange
          @moveItemToIndex view, view._index+1
          lastChange = current
        else if current < lastChange
          @moveItemToIndex view, view._index-1
          lastChange = current

      view.on 'DragFinished', =>

        view.unsetClass 'no-anim remove'

        if view.data.type isnt 'persistent' and view.getY() > 125
          view.setClass 'explode'
          KD.utils.wait 500, =>
            @removeItem view
            @updateItemPositions()
            KD.singletons.dock.saveItemOrders @items
        else
          KD.utils.wait 200, -> view.unsetClass 'on-top'
          view.setX view._index * @viewWidth
          view.setY 0
          KD.singletons.dock.saveItemOrders @items

        lastChange  = 0

  updateItemPositions:(exclude)->
    for _item, index in @items
      _item._index = index
      _item.setX index * @viewWidth  unless exclude is _item

  moveItemToIndex:(item, index)->
    super item, index
    @updateItemPositions item
