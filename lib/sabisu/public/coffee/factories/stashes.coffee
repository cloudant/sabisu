sabisu.factory 'stashesFactory', ($log, $http) ->
  factory = {}
  factory.stashes = ->
    $http.get(
      '/sensu/stashes'
    )
  factory.saveStash = (stash) ->
    $http.post(
      "/sensu/stashes",
      stash
    )
  factory.deleteStash = (path) ->
    $http.delete(
      "/sensu/stashes/#{path}"
    )
  factory
