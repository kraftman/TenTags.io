
var index = 0
var hasFocus = false

function ChangeFocus(value) {

  index = index + value;
  var numChildren = $('#posts').children().length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  $('#posts').children().eq(index).focus();
}

function OpenLink(e) {
  if ($(':focus').find(".postLink").length) {
    window.open($(':focus').find(".postLink").attr('href'), '_blank');
  }
}

function OpenComments(e) {
  if ($(':focus').find(".commentLink").length) {
    var win = window.open($(':focus').find(".commentLink").attr('href'), '_blank');
    if (win) {
      win.focus()
    }
  }
}

function Upvote(e) {
  if ($(':focus').find(".postLink").length) {
    var currentPost = $(':focus')
  }
}

function Downvote(e) {

}

Mousetrap.bind('tab', function(e) {
  e.preventDefault();

  if (hasFocus == true) {
    hasFocus = false
    Mousetrap.bind('up');
    Mousetrap.bind('down');
    Mousetrap.bind('left');
    Mousetrap.bind('right');
    Mousetrap.bind('enter');
    Mousetrap.bind('ctrl+enter');

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
    Mousetrap.bind("enter", OpenLink)
    Mousetrap.bind('ctrl+enter', OpenComments);
    Mousetrap.bind("right", Upvote)
    Mousetrap.bind("left", Downvote)
    index = 0
    $('#posts').children().eq(index).focus();
  }
})
