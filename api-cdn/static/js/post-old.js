
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



  // $(document).on('click', '.togglefiltercomment', function(e) {
  //   $(this).toggleClass('togglefilter-selected');
  //   var className = '.'+$(this).attr('data-filterID')
  //   console.log(className);
  //   $(className).toggle();
  //   e.preventDefault();
  // });

  MoveReply();
  HandleCommentVotes();

})

function HandleCommentVotes() {

}
