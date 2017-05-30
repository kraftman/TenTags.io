
var index = 0
var hasFocus = false
var hidden = {}

var newPosts = [];
var maxPosts = 10;
var seenPosts = [];
var postIndex = 10;
var list_empty;

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

  AddPostVoteListener();
  LoadNewPosts();
  AddToSeenPosts();

  AddFilterHandler();
  Drag2();
  AddInfinite();
})


function AddInfinite(){
  $(window).scroll(function() {
   if($(window).scrollTop() + $(window).height() >= ($(document).height()-50)) {

     for (var i = 1; i <= 1; i++) {
       LoadMorePosts($('.posts').children().first())
     }
   }
  });
 }


function Drag2(){
  console.log('this')
  interact('.post').draggable({
    inertia: true,
    onmove: dragMoveListener,
    onend: onEndListener,
    onstart: onStartListener,
    axis: 'x'
  })
//
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


function AddToSeenPosts(){
  $.each($('#posts').children(), function(k,v) {
    var postID = $(v).find('.postID').val()
    seenPosts.push(postID)
  })
}


function AddPostVoteListener(){
  $(".post-upvote").click(function(e) {
    e.preventDefault()
    VotePost($(this).parents('.post'), 'up')
  })
  $(".post-downvote").click(function(e){
    e.preventDefault()
    VotePost($(this).parents('.post'),'down')
  })
}



function VotePost(post, direction){

  //get the post
  var postID = $(post).children('.postID').val()
  var postHash = $(post).children('.postHash').val()
  console.log(postID, postHash)

  if (userSettings.hideVotedPosts == true) {
    if ($.inArray(postID, seenPosts) == -1){
      seenPosts.push(postID)
    }


    LoadMorePosts($(post));

    $(post).hide(0, function() {
      var nextPost = $(post).next()
      if (nextPost.length) {
        nextPost.focus()
      }
      $(post).remove();});
  }

  var uri;
  if (direction == 'up'){
    uri = '/api/post/'+postID+'/upvote?hash='+postHash
  } else {
    uri = '/api/post/'+postID+'/downvote?hash='+postHash
  }
  $(post).find('.post-upvote').addClass('disable-vote');
  $(post).find('.post-downvote').addClass('disable-vote');

  $.get(uri,function(data){
    console.log(data);
  })
}


function LoadNewPosts(startAt = 10){
  var uri = '/api/frontpage?startAt='+startAt+'&range=100'
  if (list_empty) {
    return ;
  }

  $.getJSON(uri,function(data){
    console.log(data)
    if (data.status == 'success'){
      if (data.data.length) {
        console.log('got data')
      } else {
        console.log('no data')
      }
      var count = 0
      $.each(data.data,function(k,v) {
        newPosts.push(v)
        count ++
      })
      if (count < 100) {
        list_empty = true
      }
    }
  })
}

function GetFreshPost(){
  if (newPosts.length < 10 ) {
    postIndex = postIndex + 100
    LoadNewPosts(postIndex)
  }

  var newPost = newPosts.shift()
  if (newPost == undefined) {
    return
  }

  while ($.inArray(newPost.id, seenPosts) != -1){
    newPost = newPosts.shift()
    if (newPost == undefined) {
      return
    }
  }

  return newPost
}



function LoadMorePosts(template){
  console.log(template)
  var newPost = template.clone()
  console.log(newPost)

  var postInfo = GetFreshPost()
  if (postInfo == null) {
    console.log('no post')
    return
  }
  console.log(postInfo.id)
  newPost.find('.postID').val(postInfo.id)
  newPost.find('.post-link').text(postInfo.title)
  if (postInfo.link == null && postInfo.bbID == null){

    newPost.find('.post-icon').attr('src','/static/icons/self.svg')
    newPost.find('.linkImg').hide()
  } else {
    newPost.find('.post-icon').attr('src','/icon/'+postInfo.id)
    newPost.find('.linkImg').attr('src','/icon/'+postInfo.id)
    newPost.find('.linkImg').show()

  }
  var postLink;
  if (postInfo.link == null){
    postLink = '/p/'+postInfo.shortURL || postInfo.id
  } else {
    postLink = postInfo.link
  }
  if (postInfo.text) {
    newPost.find('.postelement-text').text(postInfo.text.substring(0, 300))
  }

  newPost.find('.comment-link').attr('href','/p/'+postInfo.shortURL || postInfo.id);
  newPost.find('.comment-link').text(postInfo.commentCount+' comments')

  if (postInfo.userHasVoted == null) {
    newPost.find('.postUpvote').show()
    newPost.find('.postDownvote').show()
  } else {
    newPost.find('.postUpvote').hide()
    newPost.find('.postDownvote').hide()
  }
  var filterIcons = newPost.find('.filter-icon')
  $.each(filterIcons, function(k,v){
    $(v).hide()
  })
  $.each(postInfo.filters,function(k,v){
    var filterIcon = $(filterIcons[k])
    filterIcon.text(v.name)
    filterIcon.attr('href','/f/'+v.name);
    filterIcon.show()
  })

  $('.posts').append(newPost)
  console.log('done')
}
