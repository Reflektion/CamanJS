# Used for storing instances of CamanInstance objects such that, when Caman() is called on an 
# already initialized element, it returns that object instead of re-initializing.
class Store
  @items = {}

  @getId: (search) ->
    if typeof search is "object" then search.id else search
  
  @has: (search) -> @items[@getId(search)]?
  @get: (search) -> @items[@getId(search)]
  @put: (name, obj) -> @items[name] = obj
  @execute: (search, callback) -> callback.call @get(search), @get(search)
  @flush: (name = false) ->
    if name then delete @items[name] else @items = {}

Caman.Store = Store