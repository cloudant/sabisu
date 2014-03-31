sabisu.controller 'eventsController',
  ($scope, $log, $location, $filter, $sce, eventsFactory, stashesFactory) ->
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
    $(window).on 'focus', ->
      $scope.isActive = true
      $scope.updateEvents()
      $scope.changes()
    $(window).on 'blur', ->
      $scope.isActive = false

    # track if alt key is pressed (for appendQuery function)
    $(window).keydown (evt) ->
      $scope.alt_pressed = true if evt.which == 18
    $(window).keyup (evt) ->
      $scope.alt_pressed = false if evt.which == 18

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

    $scope.updateStashes = ->
      stashesFactory.stashes().success (data, status, headers, config) ->
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
                event.client.silence_stash = stash
                break
              else
                if check == event.check.name
                  event.check.silenced = true
                  event.check.silence_stash = stash
                  break

        $('.close_popover').click ->
          $scope.closePopovers()

        # if they click outside the popover, close it
        $('body').on 'click', (e) ->
          $('[data-toggle="popover"]').each ->
            if (!$(@).is(e.target) &&
                $(@).has(e.target).length == 0 &&
                $('.popover').has(e.target).length == 0)
              $(@).popover('hide')

        $('.glyphicon-question-sign').tooltip()

    $scope.closePopovers = ->
      $('.silenceBtn').popover('hide')

    $scope.updateSilenceDetails = (stash) ->
      parts = stash['path'].split('/', 3)
      client = parts[1]
      check = null
      check = parts[2] if parts.length > 2

      $scope.silencePath = client
      $scope.silencePath += '/' + check if check
      if stash['content']['timestamp']
        $scope.silenceCreated = $filter('date')((stash['content']['timestamp'] * 1000), 'short')
      $scope.silenceOwner = stash['content']['owner']
      if stash['content']['expiration'] == 'resolve'
        $scope.silenceExpires = 'On resolve'
        $scope.silenceExpirationClass = 'success'
      else if stash['content']['expiration'] == 'never'
        $scope.silenceExpires = 'Never'
        $scope.silenceExpirationClass = 'danger'
      else if stash['expire']? and stash['expire'] != -1
        $scope.silenceExpires = moment.unix(parseInt(stash['content']['timestamp']) +
                                parseInt(stash['expire'])).fromNow()
        $scope.silenceExpirationClass = 'warning'
      if stash['content']['reason']?
        $scope.silenceReason = stash['content']['reason']

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

    $scope.format_attr_value = (event, key, path) ->
      # use the path to index into the embedded hashes
      path = path.split('.')
      val = event
      for p in path
        if p of val
          val = val[p]
        else
          val = null
          break

      # format the value
      if val == undefined or val == null
        val = 'n/a'
      else if $scope.typeIsArray val
        val = $filter('joinBy')(val, ', ')
      else if String(val).match '^[0-9]{13}$'
        val = $filter('date')(val, 'short')
      else
        for field in $scope.event_fields
          if field.name == key && field.type == 'url'
            val = "<a href='#{val}'>goto</a>"
      $sce.trustAsHtml(String(val))

    $scope.getEventAttributes = (event) ->
      attr = {
        'left': [
          ['issued', 'check.issued'],
          ['interval', 'check.interval'],
          ['occurrences', 'occurrences']
        ].concat([i.name, i.path] for i in $scope.event_fields_custom by 2),
        'right': [
          ['state change', 'rel_time'],
          ['subscribers', 'check.subscribers'],
          ['handlers', 'check.handlers']
        ].concat([i.name, i.path] for i in $scope.event_fields_custom[1..] by 2)
      }

      for side in ['left', 'right']
        for a in attr[side]
          a[1] = $scope.format_attr_value(event, a[0], a[1])
      attr

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
      eventsFactory.searchEvents($scope.search, $scope.sort, $scope.limit, $scope.event_fields_int).
      success( (data, status, headers, config) ->
        color = [ 'success', 'warning', 'danger', 'info' ]
        status = [ 'OK', 'Warning', 'Critical', 'Unknown' ]
        events = []
        $scope.bookmark = data['bookmark'] if 'bookmark' of data
        $scope.count = data['count'] if 'count' of data

        if 'ranges' of data and
        not angular.equals($scope.previous_events_ranges,data['ranges']['status'])
          statuses = data['ranges']['status']
          $scope.previous_events_ranges = statuses
          # $('#stats_status').find('#totals').find('.label-success').text(
          #   "OK: " + statuses['OK']
          # )
          $('#stats_status').find('#totals').find('.label-warning').text(
            "Warning: " + statuses['Warning']
          )
          $('#stats_status').find('#totals').find('.label-danger').text(
            "Critical: " + statuses['Critical']
          )
          $('#stats_status').find('#totals').find('.label-info').text(
            "Unknown: " + statuses['Unknown']
          )

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
                    event.client.silence_stash = stash
                  else if check == event.check.name
                    event.check.silenced = true
                    event.check.silence_stash = stash

            # add formatted attributes
            event.attributes = $scope.getEventAttributes(event)

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
    $('.collapse').on 'hide.bs.collapse', ->
      $scope.bulk = 'show' if $scope.showDetails.length == 0

    # on show switch glyhicon
    $('.collapse').on 'show.bs.collapse', ->
      $scope.bulk = 'hide' if $scope.showDetails.length > 0

    # toggle expand/contract event
    $scope.toggleDetails = (id) ->
      if not $("#" + id).hasClass('in')
        # show the element
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
    $scope.typeIsArray = (value) ->
      value and
        typeof value is 'object' and
        value instanceof Array and
        typeof value.length is 'number' and
        typeof value.splice is 'function' and
        not ( value.propertyIsEnumerable 'length' )

    ### Keyboard Shortcuts ###
    Mousetrap.bind('?', ->
      $log.info('showing shortcuts')
      $("#keyboard_shortcuts").modal('show')
    'keyup')
    Mousetrap.bind('.', ->
      $('#search_input').focus()
    'keyup')
    Mousetrap.bind('s', ->
      $('#sort').focus()
      $('#sort').click()
    'keyup')
    Mousetrap.bind('enter', ->
      $scope.updateParams()
    'keyup')
    ##########################
