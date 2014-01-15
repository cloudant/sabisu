sabisu = angular.module('sabisu', [])

sabisu.factory('eventsFactory', ($log, $http) ->
    factory = {}
    factory.searchEvents = -> 
        search_query = $('#search_input').val()
        limit = $('#limit').val()
        if search_query == ''
            $http(
                method: 'GET'
                url: '/api/events'
                params:
                    limit: limit
            )
        else
            $http(
                method: 'GET'
                url: '/api/events/search'
                params:
                    query: search_query
                    limit: limit
            )
    factory
)

sabisu.controller('eventsController', ($scope, $log, eventsFactory) ->
    $scope.events = []

    $scope.updateEvents = ->
        eventsFactory.searchEvents().success( (data, status, headers, config) ->
            color = [ 'success', 'warning', 'danger', 'info' ]
            events = []
            $scope.bookmark = data['bookmark'] if 'bookmark' of data
            $scope.count = data['count'] if 'count' of data
            if 'events' of data
                for event in data['events']
                    event = angular.fromJson(event)
                    event['id'] = Math.floor(Math.random() * 100000000000)
                    event['color'] = color[event['status']]
                    event['color'] ?= color[0]
                    event['rel_time'] = "2 hours ago"
                    event['dotdotdot'] = ''
                    event['short_output'] = ''
                    if event['output']?
                        event['short_output'] = event['output'][0..100]
                        if event['output'].length > 100
                            event['dotdotdot'] = '...'
                    events.push event
                    
                $scope.events = events
        )
    $scope.updateEvents()

    $scope.toggleDetails = (id) ->
        $("#" + id).collapse('toggle')
)
