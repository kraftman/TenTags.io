
var index = -1
var depth = 0
var hasFocus = false
var currentParent

$(function() {
  // $('.filtername').click( function(e) {
  //
  //   $('.filter_' + $(this).html()).toggle()
  //   e.preventDefault();
  // })

  $('.comment-collapse').click( function(e) {
    e.preventDefault();

    $(this).parent().find('.commentInfo').toggle()
    $(this).parent().find('.comment-title').toggle()

  })

  $(document).on('click', '.togglefiltercomment', function(e) {
    $(this).toggleClass('togglefilter-selected');
    var className = '.'+$(this).attr('data-filterID')
    console.log(className);
    $(className).toggle();
    e.preventDefault();
  });

  MoveReply();
  HandleCommentVotes();

})

function HandleCommentVotes() {
  $('.upvotecomment-button, .downvotecomment-button').click(function(e){
    e.stopPropagation()
    console.log(e.currentTarget)
    e.preventDefault();
    console.log('/api'+$(e.currentTarget).attr('href'))
     $.get('/api'+$(e.currentTarget).attr('href'),function(data){
       console.log(data);
       if(data.error == false ){
         $(e.currentTarget).parent().children('.upvotecomment-button, .downvotecomment-button').hide()
       }
     })
  })
}

function MoveReply(){
  $('.comment-reply-button').click(function(e) {
    var parent = $(e.currentTarget).closest('.comment')
    console.log(parent)
    $('#commentform').insertAfter(parent);
    $('#commentform').children('#parentID').val($(parent).data('commentid'))
    e.preventDefault();
    e.stopPropagation();
  })
  $('.post-comments').click(function(e){

    if ($(e.target).hasClass('post-comments')) {
       $('#commentform').prependTo($('.post-comments'))
       $('#commentform').children('#parentID').val($('#postID').val())
     }
  })

}

function ChangeFocus(value) {
  if (index == -1) {
    index = 0
  } else {
    index = index + value;
  }
  var numChildren = currentParent.children(".comment").length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  currentParent.children(".comment").eq(index).focus();
}


Mousetrap.bind('tab', function(e) {
  e.preventDefault();
  currentParent = $('#comments').children(".comment").eq(0)
  currentParent.children(".comment").eq(0).focus()

  if (hasFocus == true) {
    hasFocus = false
    Mousetrap.bind('up');
    Mousetrap.bind('down');
    Mousetrap.bind('right');
    Mousetrap.bind('left');
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
    Mousetrap.bind('left', function(e) {
      e.preventDefault();
      if (currentParent.parent().children(".comment").length) {
        currentParent = currentParent.parent()
        currentParent.children(".comment").eq(0).focus()
        index = 0
      }
    });
    Mousetrap.bind('right', function(e) {
      e.preventDefault();
      if (currentParent.children(".comment").eq(0).length) {
        currentParent = currentParent.children(".comment").eq(0);
        index = 0
        currentParent.children(".comment").eq(0).focus()
      }
    });
  }
})
