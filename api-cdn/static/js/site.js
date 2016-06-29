$(function() {
  AddVoteListener();
  AddMenuHandler();
})

function AddMenuHandler(){
  $('#box-two').hide();
  $('#infoBoxLink').click(function(e){
    e.preventDefault();
    $('#box-one').show();
    $('#box-two').hide();
  })
  $('#filterBoxLink').click(function(e){
    e.preventDefault();
    $('#box-one').hide();
    $('#box-two').show();
  })
}

function AddVoteListener(){
  $(".upvote").click(function(){
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())+1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/upvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
  $(".downvote").click(function(){
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())-1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/downvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
}
