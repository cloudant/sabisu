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
    $scope.event_fields_name = []
    $scope.events_spin = false
    $scope.showAll = false
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

    if $location.search().showAll?
        $scope.showAll = $location.search().showAll
        $log.info($scope.showAll)

    $scope.buildSilencePopover = (stash) ->
        html = '<div class="silence_window">'
        if stash['content']['timestamp']?
            html = """
<dl class="dl-horizontal">
<dt>Created</dt>
<dd>#{$filter('date')((stash['content']['timestamp'] * 1000), "short")}</dd>
"""
        if stash['content']['owner']?
            html += """
<dt>Owner</dt>
<dd>#{stash['content']['owner']}</dd>
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
        if stash['content']['reason']?
            html += """
                    <dl>
                    <dt>Reason</dt>
                    <dd>#{stash['content']['reason']}</dd>
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
                $scope.event_fields_name.push field.name
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
        else if value == undefined or value == null
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
                placement: 'right'
                container: 'body'
                title: """Silence Details <button type="button" class="btn btn-link btn-xs pull-right close_popover" onclick="$('.silenceBtn').popover('hide')"><span class="glyphicon glyphicon-remove"></span>close</button>"""
            )

            $('.close_popover').click( ->
                $scope.closePopovers()
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
        $log.info('closing popovers')
        $('.silenceBtn').popover('hide')

    $scope.updateSilencePath = (path) ->
        $scope.silencePath = path

    $scope.saveSilence = ->
        valid = true
        # check that input fields are valid
        owner = $('#owner').val()
        if owner == ''
            $('.silence_owner').removeClass('has-success')
            $('.silence_owner').addClass('has-error')
            valid = false
        else
            $('.silence_owner').removeClass('has-error') 
            $('.silence_owner').addClass('has-success')
        reason = $('#reason').val()
        if reason == ''
            $('.silence_reason').removeClass('has-success')
            $('.silence_reason').addClass('has-error')
            valid = false
        else
            $('.silence_reason').removeClass('has-error')
            $('.silence_reason').addClass('has-success')

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
            stash['content']['owner'] = owner
            stash['content']['reason'] = reason
            stash['content']['expiration'] = expiration
            if expiration == 'timer'
                stash['expire'] = timerToSec(timer_val)
            stashesFactory.saveStash(stash).success( (data, status, headers, config) ->
                # update stashes displayed
                $scope.updateStashes()
                # clean the modal
                owner = $('#owner').val()
                $('.silence_owner').removeClass('has-success')
                $('.silence_owner').removeClass('has-error')
                reason = $('#reason').val()
                $('.silence_reason').removeClass('has-success')
                $('.silence_reason').removeClass('has-error')
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
            if 'rows' of data and not angular.equals($scope.previous_events_events, data.rows)
                $scope.previous_events_events = angular.copy(data.rows)
                for event in data.rows
                    event = event.doc.event
                    id = "#{event.client.name}/#{event.check.name}"
                    event.id = CryptoJS.MD5(id).toString(CryptoJS.enc.Base64)
                    if event.id in $scope.showDetails or $scope.showAll == 'true'
                        event.showdetails = 'in'
                    else
                        event.showdetails = ''
                    event.color = color[event.check.status]
                    event.wstatus = status[event.check.status]
                    if event.check.state_change == null or event.check.state_change == undefined
                        event.rel_time = 'n/a'
                    else
                        event.rel_time = moment.unix(event.check.state_change).fromNow()
                    event.check.issued = event.check.issued * 1000
                    if event.check.state_change?
                        event.check.state_change = event.check.state_change * 1000
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

    ### Keyboard Shortcuts ###
    Mousetrap.bind('?', ->
        $log.info('showing shortcuts')
        $("#keyboard_shortcuts").modal('show')
    'keyup'
    )
    Mousetrap.bind('.', ->
        $('#search_input').focus()
    'keyup'
    )
    Mousetrap.bind('s', ->
        $('#sort').focus()
        $('#sort').click()
    'keyup'
    )
    Mousetrap.bind('enter', ->
        $scope.updateParams()
    'keyup'
    )
    ##########################
)

sabisu.directive('searchTypeahead', ($log, $window, $filter, $timeout, eventsFactory) ->
    (scope, element, attrs) ->
        clause_char_list = "a-zA-Z0-9_\\-\\?\\*\\+\\~\\.\\[\\]\\{\\}\\^\""
        el = angular.element element

        # returns the current clause as [key, value] or null if none
        current_clause = () ->
            lastIndex = el.current_search_string.lastIndexOf(" ")
            el.current_search_string.substring(lastIndex + 1).split(':')

        # return the search string up until the last clause
        all_but_last_clause = () ->
            lastIndex = el.current_search_string.lastIndexOf(" ")
            a = el.current_search_string.substring(0, lastIndex)
            a = a + ' ' if a.length > 0
            a

        # is there whitespace at the end of the search string?
        whitespace_at_end = () ->
            m = el.current_search_string.match(RegExp(" $"))
            m?

        # is the cursor currently at a spot that should have no autocomplete?
        at_none = () ->
            quote_count = if (c = current_clause()) && c.length >= 2 then (c[1].split('"').length - 1) else 0
            el.current_search_string.slice(-1) == '"' && quote_count == 2

        # is the cursor currently in a spot to enter a value?
        at_val = () ->
            current_clause()? && current_clause().length == 2 && !whitespace_at_end()

        # is the cursor currently in a spot to enter a boolean?
        at_bool = () ->
            # make sure last word(s) aren't boolean
            return false if (all_but_last_clause().match(RegExp("(AND|AND NOT|OR|OR NOT) $")))
            return false if all_but_last_clause() == ''
            return true if (current_clause()? && current_clause().length == 2 && whitespace_at_end())
            unless current_clause() == null
                return true if 'AND NOT'.match(RegExp("^#{current_clause()[0]}"))?
                return true if 'OR NOT'.match(RegExp("^#{current_clause()[0]}"))?
            return false

        # is the cursor currently in a spot to enter a key?
        at_key = () ->
            !at_bool() && !at_val() && !at_none()

        # set up the typeahead plugin
        el.typeahead(
            {
                minLength: 0,
                highlight: true,
                hint: true
            },
            {
                name: 'keys',
                displayKey: 'name',
                source: (search_string, cb) ->
                    # store the current search string
                    el.current_search_string = search_string

                    # squash the search string to only the current word
                    search_word = if current_clause() then current_clause().slice(-1)[0] else ''
                    if at_key() && whitespace_at_end()
                        search_word = ''
                    search_word_clean = search_word.trim().replace(/"/, '')

                    # position the dropdown under the cursor (~ means sibling in the css selector)
                    # doesn't work in non-compliant browsers (ie IE)
                    if whitespace_at_end()
                        indent = Math.max(0, (element[0].selectionStart || 0)) * 0.535
                    else
                        if current_clause().length > 1
                            key = current_clause()[0].length + 1
                        else
                            key = 0
                        indent = Math.max(0, (element[0].selectionStart || 0) - (search_word.length + key)) * 0.535
                    
                    dd = angular.element "##{element[0].id} ~ .tt-dropdown-menu"
                    dd[0].style.left = "#{indent}em"

                    # don't display the hint if the search string is blank
                    if search_string.length == 0
                        angular.element(".tt-hint").hide()
                    else
                        angular.element(".tt-hint").show()

                    # determine if we are entering a key, boolean, or value
                    if at_val()
                        # if this is a value of a key we are indexing,
                        # show matching values in alpha order
                        key = current_clause()[0]
                        if scope.stats[key]
                            data = []
                            angular.forEach scope.stats[key], (v, k) ->
                                if v[0].trim() != "" && v[0].indexOf(search_word_clean) == 0
                                    data.push { name: "#{key}:#{v[0]}" }
                            data = $filter('orderBy')(data, 'name')
                            cb(data)
                        else
                            cb([])

                    else if at_bool()
                        cb([ { name: 'AND' }, { name: 'AND NOT' }, { name: 'OR' }, { name: 'OR NOT' } ])

                    else if at_none()
                        cb([])

                    else
                        # if we are entering a key, return all matching keys in alpha order
                        eventsFactory.event_fields().success (data, status, headers, config) ->
                            fields = []
                            # filter out any fields that are not index == true
                            for field in data
                                fields.push field if field.index
                            if search_word_clean.length > 0
                                fields = $.grep fields, (n, i) ->
                                    n.name.indexOf(search_word_clean) == 0
                            fields = $filter('orderBy')(fields, 'name')
                            cb(fields)
            }
        )

        # make sure the dropdown displays on textbox focus
        el.on 'focus', () ->
            # hacky, but I can't get this to work otherwise
            curval = el.typeahead('val')
            el.typeahead('val', 'c').typeahead('open')
            el.typeahead('val', curval).typeahead('open')

        # intercept the autocomplete and make sure it only replaces the last word
        el.on 'typeahead:selected', ($e, datum) ->
            # determine whether this is a key or value
            if at_val()
                val = datum.name.split(':')
                el.typeahead('val', all_but_last_clause() + val[0] + ':"' + val[1] + '" ')
            else if at_key()
                el.typeahead('val', all_but_last_clause() + datum.name + ':')
            else
                el.typeahead('val', all_but_last_clause() + datum.name + ' ')

            # hack to avoid the fact that the dropdown is normally closed
            $timeout () ->
                curval = el.typeahead('val')
                el.typeahead('val', 'c').typeahead('open')
                el.typeahead('val', curval).typeahead('open')
            , 100

        # if you hit tab to autocomplete a key
        el.on 'typeahead:autocompleted', ($e, datum) ->
            $log.info(datum.name)
            $log.info(el.current_search_string)
            if at_key()
                $log.info('key')
                el.typeahead('val', all_but_last_clause() + datum.name + ':')
                el.typeahead('open')
            else if at_val()
                $log.info('val')
                val = datum.name.split(':')
                el.typeahead('val', all_but_last_clause() + val[0] + ':"' + val[1] + '" ')
                el.typeahead('open')
            else
                $log.info('tab else')
                el.typeahead('val', all_but_last_clause() + datum.name + ' ')
                el.typeahead('open')

        # only change the last word when scrolling through the dropdown
        el.on 'typeahead:cursorchanged', ($e, datum, dsName) ->
            angular.element(".tt-input").val(all_but_last_clause() + datum.name)
            angular.element(".tt-hint").val("")
)

