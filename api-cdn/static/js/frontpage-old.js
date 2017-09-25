
var index = 0
var hasFocus = false
var hidden = {}

var newPosts = [];
var maxPosts = 10;
var seenPosts = [];
var postIndex = 10;
var list_empty;

$(function() {

  AddPostVoteListener();
  LoadNewPosts();
  AddToSeenPosts();


  AddFilterHandler();
  Drag2();
  //AddInfinite();
})

}





function AddInfinite(){
  $(window).scroll(function() {
   if($(window).scrollTop() + $(window).height() >= ($(document).height()-50)) {

     for (var i = 1; i <= 1; i++) {
       LoadMorePosts($('.posts').children().first())
     }
   }
  });
 }




function AddFilterHandler(){
  // take over the loading of new filters
  /*
  $('.filterbarelement').click(function(e){
    e.preventDefault();
    var filterName = $(e.target).text())
    $.getJSON('/api/f/'+filterName+'/posts?startat=1&endat=100',function(data){
      console.log(data)
      if (data.status == 'success'){
        newPosts = data.data
        console.log(newPosts.length+ ' new posts got from server')
      }
    })
  })
  */
}
