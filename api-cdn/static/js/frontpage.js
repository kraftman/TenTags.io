
var index = 0
var hasFocus = false
var hidden = {}

$(function() {
  $('.post-controls').hide();
  $( ".post" ).focus(function() {
    var postControls = $(this).find('.post-controls')
    $(postControls).show()
    console.log('showing');
  });
  $( ".post" ).focusout(function() {
    var postControls = $(this).find('.post-controls')
    $(postControls).hide();
  });
})
