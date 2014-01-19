sabisu = angular.module('sabisu', [])

sabisu.config( ($locationProvider) ->
    $locationProvider.html5Mode(true)
)

sabisu.filter('joinBy', ->
    (input, delimiter) ->
        (input || []).join(delimiter || ',')
)

sabisu.factory('eventsFactory', ($log, $http) ->
    factory = {}
    factory.searchEvents = (search_query, sort, limit) ->
        sort = sort + '<string>' unless sort == "issued" or sort == "status"
        sort = "[\"#{sort}\"]"
        if search_query == ''
            $http(
                method: 'GET'
                url: '/api/events'
                params:
                    limit: limit
                    sort: sort
                    include_docs: true
            )
        else
            $http(
                method: 'GET'
                url: '/api/events/search'
                params:
                    query: search_query
                    limit: limit
                    sort: sort
                    include_docs: true
            )
    factory
)

sabisu.controller('eventsController', ($scope, $log, $location, eventsFactory) ->
    $scope.events = []
    $scope.events_spin = false
    $scope.bulk = 'show'

    # load url parameters
    if $location.search().query?
        $scope.search_field = $location.search().query
    else
        $scope.search_field = ''

    if $location.search().sort?
        $scope.sort = $location.search().sort
    else
        $scope.sort = 'client'

    if $location.search().limit?
        $scope.limit = $location.search().limit
    else
        $scope.limit = '50'

    $scope.updateEvents = ->
        # clear any currently displayed events
        $scope.events = []
        # start progress bar
        $scope.events_spin = true
        # set url paramaters with query terms etc
        $location.search('query', $scope.search_field)
        $location.search('sort', $scope.sort)
        $location.search('limit', $scope.limit)
        # get events
        eventsFactory.searchEvents($scope.search_field, $scope.sort, $scope.limit).success( (data, status, headers, config) ->
            color = [ 'success', 'warning', 'danger', 'info' ]
            status = [ 'OK', 'Warning', 'Critical', 'Unknown' ]
            events = []
            $scope.bookmark = data['bookmark'] if 'bookmark' of data
            $scope.count = data['count'] if 'count' of data
            if 'events' of data
                for event in data['events']
                    event = angular.fromJson(event)
                    event['id'] = Math.floor(Math.random() * 100000000000)
                    event['color'] = color[event['check']['status']]
                    event['wstatus'] = status[event['check']['status']]
                    event['rel_time'] = "2 hours ago"
                    event['check']['issued'] = Date(event['check']['issued'] * 1000)
                    #event['check']['state_change'] = Date.parse(event['check']['state_change'])
                    events.push event
                # hide progress bar
                $scope.events_spin = false
                $scope.events = events
        )
    $scope.updateEvents()

    # expand/contract all events
    $scope.bulkToggleDetails = ->
        for event in $scope.events
            $("#" + event['id']).collapse($scope.bulk)

    # on hide switch glyhicon
    $('.collapse').on('hide.bs.collapse', ->
        $scope.bulk = 'show'
        $(@).parent().find('.toggleBtn').removeClass('glyphicon-collapse-up')
        $(@).parent().find('.toggleBtn').addClass('glyphicon-collapse-down')
    )
    # on shide switch glyhicon
    $('.collapse').on('show.bs.collapse', ->
        $scope.bulk = 'hide'
        $(@).parent().find('.toggleBtn').removeClass('glyphicon-collapse-down')
        $(@).parent().find('.toggleBtn').addClass('glyphicon-collapse-up')
    )

    # toggle expand/contract event
    $scope.toggleDetails = (id) ->
        $("#" + id).collapse('toggle')
)
