$(document).ready(function(){
  $("#collapseBrowser").click(function(){
    if ($("#browse_list").is(":visible")) {
      $("#browse_list").hide();
      $(".main-content").removeClass("col-md-9");
      $(".main-content").addClass("col-md-12");
      $(this).removeClass("collapseBrowserVisable");
      $(this).addClass("collapseBrowserNonVisable");
      $(this).children("span").removeClass("glyphicon-chevron-down");
      $(this).children("span").addClass("glyphicon-chevron-up");
    } else {
      $("#browse_list").show();
      $(".main-content").removeClass("col-md-12");
      $(".main-content").addClass("col-md-9");
      $(this).removeClass("collapseBrowserNonVisable");
      $(this).addClass("collapseBrowserVisable");
      $(this).children("span").removeClass("glyphicon-chevron-up");
      $(this).children("span").addClass("glyphicon-chevron-down");
    };
  });
});
