
var index = 0
var hasFocus = false

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



function ChangeFocus(value) {

  index = index + value;
  var numChildren = $('#posts').children().length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  $('#posts').children().eq(index).focus();
}

function OpenLink(e) {
  if ($(':focus').find(".postLink").length) {
    var url = $(':focus').find(".postLink").attr('href')
    console.log(url)
    window.open(url, '_blank');
  }
}

function OpenComments(e) {
  if ($(':focus').find(".commentLink").length) {
    var url = document.location.origin+$(':focus').find(".commentLink").attr('href')
    console.log(url)
    window.open(url, '_blank');

  }
}

function Upvote(e) {
  if ($(':focus').find(".postLink").length) {
    var currentPost = $(':focus')
  }
}

function Downvote(e) {
  $(':focus').hide("slide", { direction: "left" }, 200);
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
    Mousetrap.bind('space', OpenComments);
    Mousetrap.bind("right", Upvote)
    Mousetrap.bind("left", Downvote)
    index = 0
    $('#posts').children().eq(index).focus();
  }
})
