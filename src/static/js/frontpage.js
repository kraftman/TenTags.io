
var index = 0
var hasFocus = false

function ChangeFocus(value) {

  index = index + value;
  var numChildren = $('#posts').children().length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  $('#posts').children().eq(index).focus();
}

function

Mousetrap.bind('tab', function(e) {
  e.preventDefault();

  if (hasFocus == true) {
    hasFocus = false
    Mousetrap.bind('up');
    Mousetrap.bind('down');
  } else {
    hasFocus = true
    Mousetrap.bind('up', function(e) {
      e.preventDefault();
      ChangeFocus(-1);
    });
    Mousetrap.bind('down', function(e) {
      e.preventDefault();
      ChangeFocus(1);
    });
  }
})
