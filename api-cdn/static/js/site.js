var userSettings = {};
var newPosts = {};
var maxPosts = 10;
var seenPosts = [];
var userID;
var postIndex = 0;

$(function() {
  userID = $('#userID').val()
  AddTagVoteListener();
  AddPostVoteListener();
  AddMenuHandler();
  AddFilterSearch();
  GetUserSettings();
  LoadKeybinds();
  LoadNewPosts();
  AddToSeenPosts();
  AddFilterHandler();
  DraggablePosts();
})

function DraggablePosts(){
  $('.post').draggable({
    axis: "x",
    stop: function( event, ui ) {
      console.log(ui.position)

      if(ui.position.left > 100) {
        $(ui.helper).animate({ left: '1000px'}, 200,function() {Upvote(event)})
      } else if (ui.position.left < -100){
        $(ui.helper).animate({ left: '-1000px'}, 200,function() {Downvote(event)})
      } else {
        $(ui.helper).animate({ left: '0px'}, 200)
      }

    }

  })

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
  console.log(seenPosts)
}

function LoadNewPosts(startAt = 0, endAt = 100){
  var uri = '/api/frontpage?startat=1&endat=100'

  $.getJSON(uri,function(data){
    console.log(data)
    if (data.status == 'success'){
      newPosts = data.data
      console.log(newPosts.length+ ' new posts got from server')
    }
  })
}


function OpenLink(e) {
  if ($(':focus').find(".post-link").length) {
    var url = $(':focus').find(".post-link").attr('href')
    console.log(url)
    window.open(url, '_blank');
    e.preventDefault();
  }
}


function OpenComments(e) {
  if ($(':focus').find(".comment-link").length) {
    var url = document.location.origin+$(':focus').find(".comment-link").attr('href')
    console.log(url)
    window.open(url, '_blank');
    e.preventDefault();
  }

}

function Upvote(e) {
  var upvoteButton = $(':focus').find('.postUpvote')
  if (upvoteButton.length) {
    VotePost.call(upvoteButton,e);
  }
}

function Downvote(e) {
  var downvoteButton = $(':focus').find('.postDownvote')
  if (downvoteButton.length) {
    VotePost.call(downvoteButton,e);
  }
}

function MoveFocus(e) {
  e.preventDefault();
  var thisPost = $(':focus')
  if (!thisPost.hasClass('post')) {
    return
  }
  var nextPost
  if (e.key == 'ArrowUp') {
    nextPost = thisPost.prev()
  } else if (e.key == 'ArrowDown') {
    nextPost = thisPost.next()
  } else {
    console.log(e.key)
  }

  if (nextPost.length) {
    nextPost.focus()
  }
}

function LoadKeybinds(){


  Mousetrap.bind('up', MoveFocus);
  Mousetrap.bind('down', MoveFocus);
  Mousetrap.bind("enter", OpenLink)
  Mousetrap.bind('space', OpenComments);
  Mousetrap.bind("right", Upvote)
  Mousetrap.bind("left", Downvote)

  $('#posts').children().first().focus();

}

var userFilters = {};

function GetUserSettings(){
  var userID = $('#userID').val()
  if (!userID) {
    return;
  }
  $.getJSON('/api/user/'+userID+'/settings',function(data){
    console.log(data)
    if (data.status == 'success'){
      userSettings = data.data
    }
  })
}


function ChangeFocus(value) {

  index = index + value;
  var numChildren = $('#posts').children().length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  $('#posts').children().eq(index).focus();
}

function UpdateSidebar(filters){
  var filterContainer  = $('.filterContainer')
  filterContainer.empty()
  $.each(filters.data, function(index,value){
    console.log(index,value)

    filterContainer.append(" \
    <ul> \
      <a href ='/f/"+value.name+"' class='filterbarelement'> \
        <span > "+value.name+"</span> \
      </a> \
    </ul> \
    ")
  })
}

function AddFilterSearch(){
  console.log('adding this')
  $('.filter-search-form').submit(function(e){
    e.preventDefault()
  })
  $('#filterSearch').on('input', function(e) {
    e.preventDefault();
    clearTimeout($(this).data('timeout'));
    var _self = this;
    $(this).data('timeout', setTimeout(function () {
      console.log('searching')

      if (_self.value.trim()){
        $.get('/api/filter/search/'+_self.value, {
            search: _self.value
        }, UpdateSidebar);
      } else {
        $.get('/api/user/filters', {
            search: _self.value
        }, UpdateSidebar);
      }
    }, 200));
  })
}

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

function GetFreshPost(){
  var newPost = newPosts.shift()

  while ($.inArray(newPost.id, seenPosts) != -1){

    //console.log(newPost)

    newPost = newPosts.shift()

    if (newPost == undefined) {
      postIndex = postIndex + 100
      LoadNewPosts(postIndex,postIndex+100)
      newPost = newPosts.shift()
      if (newPost == undefined) {
        return
      }
    }

  }
  return newPost
}

function LoadMorePosts(template){
  var newPost = template.clone()

  $(newPost).slideDown('fast')

  var postInfo = GetFreshPost()
  if (postInfo == null) {
    return
  }
  var postID
  newPost.find('.postID').val(postInfo.id)
  newPost.find('.post-link').text(postInfo.title)

  var postLink;
  if (postInfo.link == null){
    postLink = '/post/'+postInfo.shortURL || postInfo.id
  } else {
    postLink = postInfo.link
  }

  newPost.find('.comment-link').attr('href',postLink);
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

  $('#posts').append(newPost)
}

function VotePost(e){
  var className = $('.myclass').attr('class');

  e.preventDefault();
  var postID = $(this).parent().parent().children('.postID').val()
  var postHash = $(this).parent().parent().children('.postHash').val()

  if (userSettings.hideVotedPosts) {
    console.log('this')
    if ($.inArray(postID, seenPosts) == -1){
      seenPosts.push(postID)
    }
    console.log(userSettings.hideVotedPosts)
    var nextPost = $(this).parents('.post').next()
    if (nextPost.length) {
      nextPost.focus()
    }
    LoadMorePosts($(this).parents('.post'));
    $(this).parents('.post').slideUp('fast',function() {

      $(this).remove();
    })
  }

  var uri;
  if ($(this).hasClass('postUpvote')){
    uri = '/api/post/'+postID+'/upvote?hash='+postHash
  } else {
    uri = '/api/post/'+postID+'/downvote?hash='+postHash
  }

  $.get(uri,function(data){
    console.log(data);
  })
}

function AddPostVoteListener(){
  $(".postUpvote").click(VotePost)
  $(".postDownvote").click(VotePost)
}

function AddTagVoteListener(){
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
