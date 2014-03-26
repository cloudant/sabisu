sabisu = angular.module('sabisu', [])

sabisu.config ($locationProvider) ->
  $locationProvider.html5Mode(true)

sabisu.filter 'slice', ->
  (arr, start, end) ->
    arr.slice(start,end)

sabisu.filter 'joinBy', ->
  (input, delimiter) ->
    (input || []).join(delimiter || ',')
