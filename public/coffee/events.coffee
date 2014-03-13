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
            url: '/api/changes'
            params: params
        )
    factory.last_sequence = ->
        $http(
            method: 'GET'
            url: '/api/changes'
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

sabisu.controller('eventsController', ($scope, $log, $location, $filter, $sce, eventsFactory, stashesFactory) ->
    # init vars
    $scope.first_search = true
    $scope.alt_pressed = false
    $scope.checks = []
    $scope.clients = []
    $scope.events = []
    $scope.event_fields = []
    $scope.event_fields_custom = []
    $scope.event_fields_facet = []
    $scope.event_fields_int = []
    $scope.events_spin = false
    $scope.bulk = 'show'
    $scope.isActive = true
    $scope.showDetails = []
    $scope.previous_events_ranges = {}
    $scope.previous_events_counts = {}
    $scope.previous_events_events = {}

    # track if window is focused or not
    # only update UI when focused
    $(window).on('focus', ->
        $scope.isActive = true
        $scope.updateEvents()
        $scope.changes()
    )
    $(window).on('blur', ->
        $scope.isActive = false
    )

    # track if alt key is pressed ( for appendQuery function )
    $(window).keydown( (evt) ->
        $scope.alt_pressed = true if evt.which == 18
    )
    $(window).keyup( (evt) ->
        $scope.alt_pressed = false if evt.which == 18
    )

    # load url parameters
    if $location.search().query?
        $scope.search_field = $location.search().query
        $scope.search = $location.search().query
    else
        $scope.search_field = ''
        $scope.search = ''

    if $location.search().sort?
        $scope.sort_field = $location.search().sort
        $scope.sort = $location.search().sort
    else
        $scope.sort = '-age'
        $scope.sort_field = '-age'

    if $location.search().limit?
        $scope.limit = $location.search().limit
        $scope.limit_field = $location.search().limit
    else
        $scope.limit = '50'
        $scope.limit_field = '50'

    $scope.buildSilencePopover = (stash) ->
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
        if stash['expire']? and stash['expire'] != -1
            rel_time = moment.unix(parseInt(stash['content']['timestamp']) + parseInt(stash['expire'])).fromNow()
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

    $scope.updateEventFields = ->
        eventsFactory.event_fields().success( (data, status, headers, config) ->
            defaults = [ 'client', 'check', 'status', 'state_change', 'occurrence', 'issued', 'output']
            $scope.event_fields = data
            for field in $scope.event_fields
                if field.type == 'int'
                    $scope.event_fields_int.push field.name
                    $scope.event_fields_int.push '-' + field.name
                $scope.event_fields_facet.push field.name if field.facet == true
                $scope.event_fields_custom.push field if field.name not in defaults
        ).error( (data, status, headers, config) ->
            alert "Failed to get fields"
        )

    $scope.add_event_attr_html = (key,value) ->
        if "#{value}".match '^[0-9]{13}$'
            value = $filter('date')(value, 'short')
        else if $scope.typeIsArray value
            value = $filter('joinBy')(value, ', ')
        else if value == 'undefined' or value == null
            value = 'n/a'
        else
            for field in $scope.event_fields
                if key == field.name
                    if field.type == 'url' and value?
                        value = "<a href=\"#{value}\">goto</a>"
                    break
            
        html = "<dt class='attr_title'>#{key}</dt>"
        html += "<dd class='attr_value'>#{value}</dd>"
        html

    $scope.build_event_attr_html = (event) ->
        # split custom fields into left and right columns evenly
        left_custom = (i for i in $scope.event_fields_custom by 2)
        right_custom = (i for i in $scope.event_fields_custom[1..] by 2)

        # build left dl
        left_div = "<dl class='dl-horizontal col-md-5 pull-left'>"
        left_div += $scope.add_event_attr_html('issued', event.check.issued)
        left_div += $scope.add_event_attr_html('interval', event.check.interval)
        left_div += $scope.add_event_attr_html('occurrences', event.occurrences)
        for item in left_custom
            left_div += $scope.add_event_attr_html(item.name, $scope.get_obj_attr(event, item.path))
        left_div += "</dl>"

        # build right dl
        right_div = "<dl class='dl-horizontal col-md-5 pull-left'>"
        right_div += $scope.add_event_attr_html('state change', event.rel_time)
        right_div += $scope.add_event_attr_html('subscribers', event.check.subscribers)
        right_div += $scope.add_event_attr_html('handlers', event.check.handlers)
        for item in right_custom
            right_div += $scope.add_event_attr_html(item.name, $scope.get_obj_attr(event, item.path))
        right_div += "</dl>"

        # return resulting html (left and right)
        left_div + right_div

    $scope.updateStashes = ->
        stashesFactory.stashes().success( (data, status, headers, config) ->
            stashes = []
            for stash in data
                # drop all non-silence stashes
                if stash['path'].match(/^silence\//)
                    stashes.push stash
            $scope.stashes = stashes
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
                            event.client.silence_html = $scope.buildSilencePopover(stash)
                            break
                        else
                            if check == event.check.name
                                event.check.silenced = true
                                event.check.silence_html = $scope.buildSilencePopover(stash)
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
                stash['expire'] = timerToSec(timer_val)
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

    $scope.resolveEvent = (client, check) ->
        eventsFactory.resolveEvent(client, check).success( (data, status, headers, config) ->
            $scope.updateEvents()
        ).error( (data, status, headers, config) ->
            alert "Faild to resolve event: #{client}/#{check}"
        )

    $scope.updateParams = ->
        $scope.search = $scope.search_field
        $scope.sort = $scope.sort_field
        $scope.limit = $scope.limit_field
        $location.search('query', $scope.search)
        $location.search('sort', $scope.sort)
        $location.search('limit', $scope.limit)
        $scope.updateEvents()

    $scope.appendQuery = (val, type = null, quote = true) ->
        q = ''
        if $scope.search.length > 0
            if $scope.alt_pressed
                q += ' AND NOT '
            else
                q += ' AND '
        else
            q += '*:* AND NOT ' if $scope.alt_pressed
        q += type + ':' if type?
        if quote
            q += "\"#{val}\""
        else
            q += "#{val}"
        $scope.search += q
        $scope.search_field = $scope.search
        $location.search('query', $scope.search)
        $scope.updateEvents()

    $scope.updateEvents = ->
        # start progress bar if first time
        $scope.events_spin = true if $scope.first_search
        $scope.first_search = false
        # get events
        eventsFactory.searchEvents($scope.search, $scope.sort, $scope.limit, $scope.event_fields_int).success( (data, status, headers, config) ->
            color = [ 'success', 'warning', 'danger', 'info' ]
            status = [ 'OK', 'Warning', 'Critical', 'Unknown' ]
            events = []
            $scope.bookmark = data['bookmark'] if 'bookmark' of data
            $scope.count = data['count'] if 'count' of data
            if 'ranges' of data and not angular.equals($scope.previous_events_ranges,data['ranges']['status'])
                statuses = data['ranges']['status']
                $scope.previous_events_ranges = statuses
                # $('#stats_status').find('#totals').find('.label-success').text("OK: " + statuses['OK'])
                $('#stats_status').find('#totals').find('.label-warning').text("Warning: " + statuses['Warning'])
                $('#stats_status').find('#totals').find('.label-danger').text("Critical: " + statuses['Critical'])
                $('#stats_status').find('#totals').find('.label-info').text("Unknown: " + statuses['Unknown'])
            if 'counts' of data and not angular.equals($scope.previous_events_counts,data['counts'])
                $scope.previous_events_counts = data['counts']
                
                stats = {}
                for field of data['counts']
                    stats[field] = []
                    for k,v of data['counts'][field]
                        stats[field].push [k, v]
                    stats[field].sort( (a,b) ->
                        a[1] - b[1]
                    ).reverse()

                $scope.stats = stats
            if 'rows' of data and not angular.equals($scope.previous_events_events, data['rows'])
                $scope.previous_events_events = angular.copy(data['rows'])
                for event in data['rows']
                    event = event['doc']['event']
                    id = "#{event['client']['name']}/#{event['check']['name']}"
                    event['id'] = CryptoJS.MD5(id).toString(CryptoJS.enc.Base64)
                    if event.id in $scope.showDetails
                        event.showdetails = 'in'
                    else
                        event.showdetails = ''
                    event['color'] = color[event['check']['status']]
                    event['wstatus'] = status[event['check']['status']]
                    event['rel_time'] = moment.unix(event['check']['state_change']).fromNow()
                    event['check']['issued'] = event['check']['issued'] * 1000
                    if event['check']['state_change']?
                        event['check']['state_change'] = event['check']['state_change'] * 1000
                    # add silence info
                    event.client.silenced ?= false
                    event.check.silenced ?= false
                    if $scope.stashes?
                        for stash in $scope.stashes
                            parts = stash['path'].split('/', 3)
                            client = parts[1]
                            if parts.length > 2
                                check = parts[2]
                            else
                                check = null
                            if client == event.client.name
                                if check == null
                                    event.client.silenced = true
                                    event.client.silence_html = $scope.buildSilencePopover(stash)
                                else if check == event.check.name
                                    event.check.silenced = true
                                    event.check.silence_html = $scope.buildSilencePopover(stash)
                    events.push event
                # hide progress bar
                $scope.events_spin = false
                if not angular.equals($scope.events, events)
                    $scope.events = events
                    $scope.updateStashes()
            $scope.events_spin = false
            $('#corner_status').text("Last Update: " + $filter('date')(Date.now(), 'mediumTime'))
        )

    $scope.updateEventFields()
    $scope.updateEvents()

    $scope.changes = ->
        $log.info "STARTING _CHANGES FEED"
        params = { feed: 'longpoll', heartbeat: 10000 }
        if $scope.last_seq?
            params['since'] = $scope.last_seq
            eventsFactory.changes(params).success( (data, status, headers, config) ->
                $scope.last_seq = data['last_seq']
                $scope.updateEvents()
                # start a new changes feed (intentional infinite loop)
                $scope.changes() if $scope.isActive == true
            ).error( (data, status, headers, config) ->
                $log.error "failed changes request (#{status}) - #{data}"
                # start a new changes feed (intentional infinite loop)
                $scope.changes() if $scope.isActive == true
            )

    $scope.get_sequence = ->
        eventsFactory.last_sequence().success( (data, status, headers, config) ->
            $scope.last_seq = data['last_seq']
            $log.info $scope.last_seq
            $scope.changes()
        )

    # disabling get_sequence to disable real-time updates
    # real-time updates is an experimental feature that is
    # not ready for prime time.
    $scope.get_sequence()

    # expand/contract all events
    $scope.bulkToggleDetails = ->
        if $scope.bulk == 'show'
            action = 'show'
            $scope.showDetails = []
            for event in $scope.events
                $scope.showDetails.push event.id
        else
            action = 'hide'
            $scope.showDetails = []
        for event in $scope.events
            $("#" + event.id).collapse(action)

    # on hide switch glyhicon
    $('.collapse').on('hide.bs.collapse', ->
        $scope.bulk = 'show' if $scope.showDetails.length == 0
    )
    # on show switch glyhicon
    $('.collapse').on('show.bs.collapse', ->
        $scope.bulk = 'hide' if $scope.showDetails.length > 0
    )

    # toggle expand/contract event
    $scope.toggleDetails = (id) ->
        if not $("#" + id).hasClass('in')
            $("#" + id).collapse('show')
            $scope.showDetails.push id if $scope.showDetails.indexOf(id) == -1
            # flip the button
            $("#" + id).parent().find('.toggleBtnIcon').removeClass('glyphicon-collapse-down')
            $("#" + id).parent().find('.toggleBtnIcon').addClass('glyphicon-collapse-up')
        else
            $("#" + id).collapse('hide')
            i = $scope.showDetails.indexOf(id)
            $scope.showDetails.splice(i, 1) if i != -1
            # flip the button
            $("#" + id).parent().find('.toggleBtnIcon').removeClass('glyphicon-collapse-up')
            $("#" + id).parent().find('.toggleBtnIcon').addClass('glyphicon-collapse-down')

    $scope.togglePopover = ->
        $(@).popover()
        $(@).popover('toggle')

    # test if variable is an array
    $scope.typeIsArray = ( value ) ->
        value and
            typeof value is 'object' and
            value instanceof Array and
            typeof value.length is 'number' and
            typeof value.splice is 'function' and
            not ( value.propertyIsEnumerable 'length' )

    $scope.to_trusted = (html_code) ->
        $sce.trustAsHtml(html_code)

    $scope.get_obj_attr = (obj, path) ->
        path = path.split('.')
        val = obj
        for p in path
            if p of val
                val = val[p]
            else
                val = null
                break
        val
)
