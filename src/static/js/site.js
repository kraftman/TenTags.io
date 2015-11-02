$(function() {
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
})
