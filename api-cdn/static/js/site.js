
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
//  DraggablePosts();
  Drag2();
  FilterToggle()
})

function Drag2(){
  console.log('this')
  interact('.post').draggable({
    inertia: true,
    onmove: dragMoveListener,
    onend: onEndListener,
    restrict: {
      restriction: "parent",
      endOnly: true,
      elementRect: { top: 0, left: 0, bottom: 1, right: 1 }

    }
  })

}

function onEndListener(event){
  var target = event.target
  var x = (parseFloat(target.getAttribute('data-x')) || 0) + event.dx
  var y = 0;
  console.log(x, x < 100, typeof(x))
  console.log(event)
  if ((x>=0 && x > -200)) {
    console.log('resetting')
    target.style.webkitTransform =
    target.style.transform =
    'translate(' + 0 + 'px, ' + y + 'px)';

    target.setAttribute('data-x', 0);
    target.setAttribute('data-y', 0);
  }

}


  function dragMoveListener (event) {
    var target = event.target,
        // keep the dragged position in the data-x/data-y attributes
        x = (parseFloat(target.getAttribute('data-x')) || 0) + event.dx
        y = 0 //(parseFloat(target.getAttribute('data-y')) || 0) + event.dy;


    // translate the element
    target.style.webkitTransform =
    target.style.transform =
      'translate(' + x + 'px, ' + y + 'px)';

    // update the posiion attributes
    target.setAttribute('data-x', x);
    target.setAttribute('data-y', y);
  }

function SubmitLogin(){

  console.log('done')
  document.getElementById("register").submit();
}

function FilterToggle(){
  var $hamburger = $(".hamburger");
  $hamburger.on("click", function(e) {
    $hamburger.toggleClass("is-active");
    console.log('that')
    // Do something else, like open/close menu
    var filterBar = $('.filter-bar')
    filterBar.toggle()
  });

  $('.toggle-filterstyle').click(function(e){
    $('.filter-styles').toggle()
    e.preventDefault();
  })

}

function DraggablePosts(){
  $('.post').draggable({
    axis: "x",
    stop: function( event, ui ) {

      if(ui.position.left > 100) {
        VotePost(this,'up')
      } else if (ui.position.left < -100){
        VotePost(this,'down')
      }
      $(ui.helper).animate({ left: '0px'}, 200)
    }
  })
}


function Upvote(e) {
  var post = $(':focus')

  if (post.length) {
    VotePost(post, 'up');
  }
}

function Downvote(e) {
  var post = $(':focus')
  console.log(post)
  if (post.length) {
    console.log(2)
    VotePost(post, 'down');
  }
}


function AddPostVoteListener(){
  $(".postUpvote").click(function(e) {
    e.preventDefault()
    VotePost($(this).parent().parent(), 'up')
  })
  $(".postDownvote").click(function(e){
    e.preventDefault()
    VotePost($(this).parent().parent(),'down')
  })
}


function VotePost(post, direction){

  //get the post
  var postID = $(post).children('.postID').val()
  var postHash = $(post).children('.postHash').val()

  if (userSettings.hideVotedPosts == '1') {
    if ($.inArray(postID, seenPosts) == -1){
      seenPosts.push(postID)
    }


    LoadMorePosts($(post).parents('.post'));

    $(post).hide("slide", { direction: direction == 'up' && 'right' || 'left'}, 200, function() {
      var nextPost = $(post).next()
      console.log(nextPost)
      if (nextPost.length) {
        nextPost.focus()
      }
      $(post).remove();});
    //$(post).show("slide", { direction: "right" }, 100);
    // $(post).parents('.post').slideUp('fast',function() {
    //   $(post).remove();
    // })
  }

  var uri;
  if (direction == 'up'){
    $(post).css('border', 'solid 1px green');
    uri = '/api/post/'+postID+'/upvote?hash='+postHash
  } else {
    $(post).css('border', 'solid 1px red');
    uri = '/api/post/'+postID+'/downvote?hash='+postHash
  }

  $.get(uri,function(data){
    //console.log(data);
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
  $('.settings-link a').click(function(e){

    $('.settings-menu').toggle()

    e.preventDefault();
  })
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
