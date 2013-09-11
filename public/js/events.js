$(document).ready(function(){
  $("#collapseStats").click(function(){
    $("#stats_field").toggle();
  });
  $("#collapseFilters").click(function(){
    $("#filters_field").toggle();
  });
  $("#collapseBrowser").click(function(){
    if ($("#browse_list").is(":visible")) {
      $("#browse_list").hide();
      $(".main-content").removeClass("col-md-9");
      $(".main-content").addClass("col-md-12");
    } else {
      $("#browse_list").show();
      $(".main-content").removeClass("col-md-12");
      $(".main-content").addClass("col-md-9");
    };
  });
});
