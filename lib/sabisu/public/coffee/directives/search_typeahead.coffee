sabisu.directive 'searchTypeahead', ($log, $window, $filter, $timeout, eventsFactory) ->
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
      c = current_clause()
      quote_count = 0
      quote_count = c[1].split('"').length - 1 if c.length >= 2
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
          sel_start = element[0].selectionStart || 0
          if whitespace_at_end()
            indent = Math.max(0, sel_start) * 0.535
          else
            if current_clause().length > 1
              key = current_clause()[0].length + 1
            else
              key = 0
            indent = Math.max(0, sel_start - (search_word.length + key)) * 0.535

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
      curval = scope.search_field
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
      scope.search_field = el.typeahead('val')

      # hack to avoid the fact that the dropdown is normally closed
      $timeout () ->
        curval = el.typeahead('val')
        el.typeahead('val', 'c').typeahead('open')
        el.typeahead('val', curval).typeahead('open')
      , 100

    # if you hit tab to autocomplete a key
    el.on 'typeahead:autocompleted', ($e, datum) ->
      if at_key()
        el.typeahead('val', all_but_last_clause() + datum.name + ':')
      else if at_val()
        val = datum.name.split(':')
        el.typeahead('val', all_but_last_clause() + val[0] + ':"' + val[1] + '" ')
      else
        el.typeahead('val', all_but_last_clause() + datum.name + ' ')
      scope.search_field = el.typeahead('val')
      el.typeahead('open')

    # only change the last word when scrolling through the dropdown
    el.on 'typeahead:cursorchanged', ($e, datum, dsName) ->
      angular.element(".tt-input").val(all_but_last_clause() + datum.name)
      angular.element(".tt-hint").val("")
