
### sort array of object by value
sortArrOfObjectsByParam = (arrToSort, strObjParamToSortBy, sortAscending) ->
    sortAscending = true if sortAscending == undefined
    if sortAscending
        arrToSort.sort( (a, b) ->
            a[strObjParamToSortBy] > b[strObjParamToSortBy]
        )
    else
        arrToSort.sort( (a, b) ->
            a[strObjParamToSortBy] < b[strObjParamToSortBy]
        )
###
