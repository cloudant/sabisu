sabisu.factory 'eventsFactory', ($log, $http) ->
  factory = {}
  factory.searchEvents = (search_query, sort, limit, ints) ->
    sort = 'state_change' if sort == 'age'
    sort = '-state_change' if sort == '-age'
    sort = sort + '<string>' unless sort in ints
    sort = "[\"#{sort}\"]"
    search_query = '*:*' if search_query == ''
    $http(
      method: 'GET'
      url: '/api/events/search'
      params:
        query: search_query
        limit: limit
        sort: sort
    )
  factory.resolveEvent = (client, check) ->
    $http(
      method: 'POST'
      url: '/sensu/resolve'
      data:
        client: client
        check: check
    )
  factory.changes = (params) ->
    $http(
      method: 'GET'
      url: '/api/events/changes'
      params: params
    )
  factory.last_sequence = ->
    $http(
      method: 'GET'
      url: '/api/events/changes'
      params:
        limit: 1
        descending: true
    )
  factory.event_fields = ->
    $http(
      method: 'GET'
      url: '/api/configuration/fields'
    )
  factory
