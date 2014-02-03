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
                rel_time = moment.unix(parseInt(stash['content']['expires'])).fromNow()
                html += """
  <dt class="text-warning">Expires</dt>
  <dd class="text-warning">#{rel_time}</dd>
"""
            if stash['content']['expiration'] == 'resolve'
                html += """
  <dt class="text-success">Expires</dt>
  <dd class="text-success">On resolve</dt>
"""
            if stash['content']['expiration'] == 'never'
                html += """
  <dt class="text-danger">Expires</dt>
  <dd class="text-danger">Never</dt>
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
<button type="button" class="deleteSilenceBtn btn btn-danger btn-sm pull-right" onclick="angular.element($('#eventsController')).scope().deleteSilence('#{stash['path']}')">
    <span class="glyphicon glyphicon-remove"></span> Delete
</button>
"""
            html += "</div>"

        stashesFactory.stashes().success( (data, status, headers, config) ->
            for stash in data
                # drop all non-silence stashes
                if stash['path'].match(/^silence\//)
                    $scope.stashes.push stash

            # clear old stash data if exists
            for event in $scope.events
                delete event.client.silenced if event.client.silenced?
                delete event.client.silence_html if event.client.silence_html?
                delete event.check.silenced if event.check.silenced?
                delete event.check.silence_html if event.check.silence_html?

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
                            break
                        else
                            if check == event.check.name
                                event.check.silenced = true
                                event.check.silence_html = buildSilencePopover(stash)
                                break
            $('.silenceBtn').popover(
                trigger: 'click'
                html: true
                placement: 'top'
                container: 'body'
                title: """Silence Details <button type="button" class="btn btn-link btn-xs pull-right close_popover" onclick="$('.silenceBtn').popover('hide')"><span class="glyphicon glyphicon-remove"></span>close</button>"""
            )

            $('.close_popover').click( ->
                $('.silenceBtn').popover('hide')
            )

            # if they click outside the popover, close it
            $('body').on('click', (e) ->
                $('[data-toggle="popover"]').each( ->
                    if (!$(@).is(e.target) && $(@).has(e.target).length == 0 && $('.popover').has(e.target).length == 0)
                        $(@).popover('hide')
                )
            )

            $('.glyphicon-question-sign').tooltip(
            )
        )

    $scope.closePopovers = ->
        $('.silenceBtn').popover('hide')

    $scope.updateSilencePath = (path) ->
        $scope.silencePath = path

    $scope.saveSilence = ->
        valid = true
        # check that input fields are valid
        author = $('#author').val()
        if author == ''
            $('.silence_author').removeClass('has-success')
            $('.silence_author').addClass('has-error')
            valid = false
        else
            $('.silence_author').removeClass('has-error') 
            $('.silence_author').addClass('has-success')
        comment = $('#comment').val()
        if comment == ''
            $('.silence_comment').removeClass('has-success')
            $('.silence_comment').addClass('has-error')
            valid = false
        else
            $('.silence_comment').removeClass('has-error')
            $('.silence_comment').addClass('has-success')

        timer_val = $('#timer_val').val()
        expiration = $('input[name=expiration]:checked', '#silence_form').val()
        if expiration == 'timer'
            re = new RegExp('^\\d*(m|h|d|w)$')
            if re.test(timer_val)
                $('.silence_timer_val').removeClass('has-error')
                $('.silence_timer_val').addClass('has-success')
            else
                $('.silence_timer_val').removeClass('has-success')
                $('.silence_timer_val').addClass('has-error')
                valid = false
        else
            $('.silence_timer_val').removeClass('has-error')
            $('.silence_timer_val').removeClass('has-success')

        # convert timer_val from shorthand to number of total seconds
        timerToSec = (val) ->
            q = new RegExp('^\\d*')
            u = new RegExp('[a-z]$')
            conversion =
                m: 60
                h: 60 * 60
                d: 60 * 60 * 24
                w: 60 * 60 * 24 * 7
            quantity = val.match(q)[0]
            unit = val.match(u)[0]
            quantity * conversion[unit]

        # if field validity checks are good, save it
        if valid
            stash = {}
            stash['path'] = "silence/" + $scope.silencePath
            stash['content'] = {}
            stash['content']['timestamp'] = Math.round( (new Date().getTime()) / 1000)
            stash['content']['author'] = author
            stash['content']['comment'] = comment
            stash['content']['expiration'] = expiration
            if expiration == 'timer'
                stash['content']['expires'] = (Math.round( (new Date().getTime()) / 1000)) + timerToSec(timer_val)
            stashesFactory.saveStash(stash).success( (data, status, headers, config) ->
                # update stashes displayed
                $scope.updateStashes()
                # clean the modal
                author = $('#author').val()
                $('.silence_author').removeClass('has-success')
                $('.silence_author').removeClass('has-error')
                comment = $('#comment').val()
                $('.silence_comment').removeClass('has-success')
                $('.silence_comment').removeClass('has-error')
                timer_val = $('#timer_val').val()
                expiration = $('input[name=expiration]:checked', '#silence_form').val()
                $('.silence_timer_val').removeClass('has-error')
                $('.silence_timer_val').removeClass('has-success')
                # close the modal
                $('#silence_window').modal('hide')
            ).error( (data, status, headers, config) ->
                alert "Failed to silence: (#{status}) #{data}"
            )

    $scope.deleteSilence = (path) ->
        stashesFactory.deleteStash(path).success( (data, status, headers, config) ->
            $scope.updateStashes()
            $scope.closePopovers()
        ).error( (data, status, headers, config) ->
            alert "Failed to delete silence"
        )

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
