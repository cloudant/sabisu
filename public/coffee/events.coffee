$(document).ready ->
    $("#collapseBrowser").click ->
        if $("#browse_list").is(":visible")
            $("#browse_list").hide()
            $(".main-content").removeClass("col-md-9")
            $(".main-content").addClass("col-md-12")
            $(@).removeClass("collapseBrowserVisable")
            $(@).addClass("collapseBrowserNonVisable")
            $(@).children("span").removeClass("glyphicon-chevron-down")
            $(@).children("span").addClass("glyphicon-chevron-up")
        else
            $("#browse_list").show()
            $(".main-content").removeClass("col-md-12")
            $(".main-content").addClass("col-md-9")
            $(@).removeClass("collapseBrowserNonVisable")
            $(@).addClass("collapseBrowserVisable")
            $(@).children("span").removeClass("glyphicon-chevron-up")
            $(@).children("span").addClass("glyphicon-chevron-down")

    $(".event_line").click ->
        $("#" + $(@).next().attr("id")).collapse('toggle')

