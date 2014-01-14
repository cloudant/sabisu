sabisu = angular.module('sabisu', [])

sabisu.factory('eventsFactory', ($log, $http) ->
    factory = {}
    factory.searchEvents = -> 
        $log.info 'searching for events'
        if $("#search").val() == ''
            $http(
                method: 'GET',
                url: '/api/events',
                params:
                    limit: 10
            )
        else
            $http(
                method: 'GET',
                url: '/api/events/search',
                params:
                    query: $("#search").val(),
                    limit: 10
            )
    factory
)

sabisu.controller('eventsController', ($scope, $log, eventsFactory) ->
    $scope.events = []

    updateEvents = ->
        eventsFactory.searchEvents().success( (data, status, headers, config) ->
            color = [ 'success', 'warning', 'danger', 'info' ]
            events = []
            for event in data
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
                
            $log.info 'got events'
            $log.info(events)
            $scope.events = events
        )
    updateEvents()

    $scope.toggleDetails = (id) ->
        $log.info "toggle #{id}"
        $("#" + id).collapse('toggle')
)
