sabisu = angular.module('sabisu', [])

sabisu.config( ($locationProvider) ->
    $locationProvider.html5Mode(true)
)

sabisu.filter('slice', ->
    (arr, start, end) ->
        arr.slice(start,end)
)

sabisu.filter('joinBy', ->
    (input, delimiter) ->
        (input || []).join(delimiter || ',')
)

sabisu.factory('eventsFactory', ($log, $http) ->
    factory = {}
    factory.searchEvents = (search_query, sort, limit) ->
        sort = sort + '<string>' unless sort == "issued" or sort == "status" or sort == "occurences"
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
    factory
)

sabisu.factory('stashesFactory', ($log, $http) ->
    factory = {}
    factory.stashes = ->
        $http(
            method: 'GET'
            url: '/sensu/stashes'
        )
    factory
)

sabisu.controller('eventsController', ($scope, $log, $location, $filter, eventsFactory, stashesFactory) ->
    $scope.checks = []
    $scope.clients = []
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

    $scope.updateStashes = ->
        $scope.stashes = []
        buildSilencePopover = (stash) ->
            stash['content']['author'] = "cbarraford"
            stash['content']['comment'] = "herp herp derp"
            stash['content']['expires'] = "8 hours"
            html = '<div class="silence_window">'
            if stash['content']['timestamp']?
                html = """
<dl class="dl-horizontal">
  <dt>Created</dt>
  <dd>#{$filter('date')((stash['content']['timestamp'] * 1000), "short")}</dd>
"""
            if stash['content']['author']?
                html += """
  <dt>Author</dt>
  <dd>#{stash['content']['author']}</dd>
"""
            if stash['content']['expires']?
                html += """
  <dt class="text-danger">Expires in</dt>
  <dd class="text-danger">#{stash['content']['expires']}</dd>
"""
            if stash['content']['on_resolve']?
                html += """
  <dt class="text-success">Delete on resolve</dt>
"""
            html += "</dl>"
            if stash['content']['comment']?
                html += """
<dl>
  <dt>Comment</dt>
  <dd>#{stash['content']['comment']}</dd>
</dl>
"""
            html += """
<button type="button" class="deleteSilenceBtn btn btn-danger btn-sm pull-right">
    <span class="glyphicon glyphicon-remove"></span> Delete
</button>
"""
            html += "</div>"

        stashesFactory.stashes().success( (data, status, headers, config) ->
            for stash in data
                # drop all non-silence stashes
                if stash['path'].match(/^silence\//)
                    $scope.stashes.push stash

            for stash in $scope.stashes
                parts = stash['path'].split('/', 3)
                client = parts[1]
                if parts.length > 2
                    check = parts[2]
                else
                    check = null
                for event in $scope.events
                    event.client.silenced ?= false
                    event.check.silenced ?= false
                    if client == event.client.name
                        if check == null
                            event.client.silenced = true
                            event.client.silence_html = buildSilencePopover(stash)
                        else
                            if check == event.check.name
                                event.check.silenced = true
                                event.check.silence_html = buildSilencePopover(stash)
            $('.silenceBtn').popover(
                trigger: 'click'
                html: true
                placement: 'top'
                container: 'body'
                title: """Silence Details <button type="button" class="btn btn-link btn-xs pull-right"><span class="glyphicon glyphicon-remove"></span>close</button>"""
            )
        )

    $scope.closePopovers = ->
        $log.info 'closing popovers'
        $('.silenceBtn').popover('hide')

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
            if 'ranges' of data
                statuses = data['ranges']['status']
                $('#stats_status').find('#totals').find('.label-success').text("OK: " + statuses['OK'])
                $('#stats_status').find('#totals').find('.label-warning').text("Warning: " + statuses['Warning'])
                $('#stats_status').find('#totals').find('.label-danger').text("Critical: " + statuses['Critical'])
                $('#stats_status').find('#totals').find('.label-info').text("Unknown: " + statuses['Unknown'])
                statuses_data = [
                    {
                        value: statuses['OK']
                        color: "#18bc9c"
                        label: 'OK'
                        labelColor: 'white'
                    },
                    {
                        value: statuses['Warning']
                        color: "#f39c12"
                        label: 'Warning'
                        labelColor: 'white'
                    }
                    {
                        value: statuses['Critical']
                        color: "#e74c3c"
                        label: 'Critical'
                        labelColor: 'white'
                    },
                    {
                        value: statuses['Unknown']
                        color: "#3498db"
                        label: 'Unknown'
                        labelColor: 'white'
                    }
                ]
                ctx = $('#chart_pie_status').get(0).getContext('2d')
                new Chart(ctx).Pie(statuses_data)
            if 'counts' of data
                # get check counts
                checks = data['counts']['check']
                datapoints = []
                for k,v of checks
                    datapoints.push [k, v]
                datapoints.sort( (a, b) ->
                    a[1] - b[1]
                )
                $scope.checks = datapoints.reverse()

                # get client counts
                checks = data['counts']['client']
                datapoints = []
                for k,v of checks
                    datapoints.push [k, v]
                datapoints.sort( (a, b) ->
                    a[1] - b[1]
                )
                $scope.clients = datapoints.reverse()
            if 'rows' of data
                for event in data['rows']
                    event = event['doc']['event']
                    event['id'] = Math.floor(Math.random() * 100000000000)
                    event['color'] = color[event['check']['status']]
                    event['wstatus'] = status[event['check']['status']]
                    event['rel_time'] = "2 hours ago"
                    event['check']['issued'] = event['check']['issued'] * 1000
                    if event['check']['state_change']?
                        event['check']['state_change'] = event['check']['state_change'] * 1000
                    events.push event
                $scope.updateStashes()
                # hide progress bar
                $scope.events_spin = false
                $scope.events = events
        )
    $scope.updateEvents()

    # expand/contract all events
    $scope.bulkToggleDetails = ->
        mySwitch = $scope.bulk
        for event in $scope.events
            $("#" + event['id']).collapse(mySwitch)

    # on hide switch glyhicon
    $('.collapse').on('hide.bs.collapse', ->
        $scope.bulk = 'show'
        $(@).parent().find('.toggleBtnIcon').removeClass('glyphicon-collapse-up')
        $(@).parent().find('.toggleBtnIcon').addClass('glyphicon-collapse-down')
    )
    # on show switch glyhicon
    $('.collapse').on('show.bs.collapse', ->
        $scope.bulk = 'hide'
        $(@).parent().find('.toggleBtnIcon').removeClass('glyphicon-collapse-down')
        $(@).parent().find('.toggleBtnIcon').addClass('glyphicon-collapse-up')
    )

    # toggle expand/contract event
    $scope.toggleDetails = (id) ->
        $("#" + id).collapse('toggle')

    $scope.togglePopover = ->
        $(@).popover()
        $(@).popover('toggle')
)
