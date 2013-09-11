$(document).ready(function(){
  $("#collapseStats").click(function(){
    if ($("#stats_field").is(":visible")) {
      $("#stats_field").hide();
      $(this).children("span").removeClass("glyphicon-chevron-up");
      $(this).children("span").addClass("glyphicon-chevron-down");
    } else {
      $("#stats_field").show();
      $(this).children("span").removeClass("glyphicon-chevron-down");
      $(this).children("span").addClass("glyphicon-chevron-up");
    };
  });
  $("#collapseFilters").click(function(){
    if ($("#filters_field").is(":visible")) {
      $("#filters_field").hide();
      $(this).children("span").removeClass("glyphicon-chevron-up");
      $(this).children("span").addClass("glyphicon-chevron-down");
    } else {
      $("#filters_field").show();
      $(this).children("span").removeClass("glyphicon-chevron-down");
      $(this).children("span").addClass("glyphicon-chevron-up");
    };
  });
  $("#collapseBrowser").click(function(){
    if ($("#browse_list").is(":visible")) {
      $("#browse_list").hide();
      $(".main-content").removeClass("col-md-9");
      $(".main-content").addClass("col-md-12");
      $(this).children("span").removeClass("glyphicon-chevron-down");
      $(this).children("span").addClass("glyphicon-chevron-up");
    } else {
      $("#browse_list").show();
      $(".main-content").removeClass("col-md-12");
      $(".main-content").addClass("col-md-9");
      $(this).children("span").removeClass("glyphicon-chevron-up");
      $(this).children("span").addClass("glyphicon-chevron-down");
    };
  });
});
