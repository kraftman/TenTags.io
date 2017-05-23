

var userSettings = {};
var newPosts = [];
var maxPosts = 10;
var seenPosts = [];
var userID;
var postIndex = 0;
var userFilters = [];

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
  LoadUserFilters();
//  DraggablePosts();
  Drag2();
  FilterToggle()
  Recaptcha()
  AddInfoBar();
  HookSubClick();
  AddInfinite();

  //$('.settings-menu').focusout(function(){
  //  $('.settings-menu').hide()
  //})
})

function AddInfinite(){
  $(window).scroll(function() {
   if($(window).scrollTop() + $(window).height() > ($(document).height()-50)) {

     for (var i = 1; i < 10; i++) {
       LoadMorePosts($('.posts').children().last())
     }
   }
  });
 }


function HookSubClick(){
  $('.filterbar-subscribe').click(function(e){
    e.preventDefault();

    var button = $(e.currentTarget)

    var buttonChild = button.children('span')
    if (buttonChild.hasClass('ti-close')){
      buttonChild.removeClass('ti-close')
      buttonChild.addClass('ti-star')
    } else {
      buttonChild.removeClass('ti-star')
      buttonChild.addClass('ti-close')
    }
    var filterID = button.attr('data-filterid')
    console.log(filterID)
    if (filterID != undefined ){
      $.get('/api/filter/'+filterID+'/sub', function(data){
        console.log(data)
      });
    }

  })
}

function LoadUserFilters(){
  var userID = $('#userID').val()
  if (!userID) {
    console.log('couldnt get userID')
    return;
  }

  $.get('/api/user/filters', function(data){
    console.log(data)
    if(data.error == false) {
      userFilters = data.data
    }
  });
}

function AddInfoBar(){
  $('.infobar-title').click(function(e){
    $('.infobar-body').toggle()
    e.preventDefault()
  })

}

function Recaptcha(){
  $('.form-login').focusin(function(){
    $('.form-login > div').show()
  })

  $('.form-login').focusout(function(){
    $('.form-login > div').hide();
  })
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

function onStartListener(event){

  $(event.target).children('a').click(function(e){e.preventDefault()})
  console.log('this started')
}

function onEndListener(event){
  var target = event.target
  var x = (parseFloat(target.getAttribute('data-x')) || 0) + event.dx
  console.log(x)

  $(event.target).children('a').off('click');
  var y = 0;

  event.preventDefault();
  console.log(event.dx)
  if ((event.dx<=0 && event.dx < -200)) {
    console.log('voting down')
    VotePost(event.target,'down')
  } else if ((event.dx>0 && event.dx> 200)){
    console.log('voting up')
    VotePost(event.target,'up')

  } else {

  }


  target.style.webkitTransform =
  target.style.transform =
  'translate(' + 0 + 'px, ' + y + 'px)';

  target.setAttribute('data-x', 0);
  target.setAttribute('data-y', 0);

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
  var filterBar = $('.filter-bar')

  var $hamburger = $(".hamburger");
  $hamburger.click(function(e) {
    e.stopPropagation();
    console.log('this')
    $hamburger.toggleClass("is-active");

    var display = filterBar.css('display');
    if (display === 'flex' || display ==='table-cell') {
      filterBar.css('display',"none");
      console.log('hiding filtebar')
    } else {

      if($(window).width() < 481) {
        filterBar.css('display','flex')
        filterBar.focus()
        filterBar.focusout(function(e){
          console.log(e)
          if ($(e.relatedTarget).parents('.filter-bar').length){
            console.log('thisjiuh')
          } else {
            console.log('nope')
            filterBar.hide()
          }
        })


      } else {
        filterBar.css('display',"table-cell");
      }
    }

  });

  $('.toggle-filterstyle').click(function(e){
    $('.filter-styles').toggle()
    e.preventDefault();
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

  //$.get(uri,function(data){
    //console.log(data);
  //})
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

function LoadNewPosts(startAt = 0, endAt = 100){
  var uri = '/api/frontpage?startat=1&endat=100'

  $.getJSON(uri,function(data){
    console.log(data)
    if (data.status == 'success'){

      newPosts = data.data

      if (data.data == 'undefined') {
        newPosts = []
      }
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

function UserHasFilter(filterID){
  var found = null;
  $.each(userFilters, function(k,v){

    if (v.id == filterID) {
      console.log('found')
      found = true;
      return;
    }

  })
  return found;
}

function UpdateSidebar(filters){
  var filterContainer  = $('.filterbar-results')
  filterContainer.empty()
  $.each(filters.data, function(index,value){


    //filterContainer.append(
    var filterBarElement = `
    <ul class = 'filterbarelement'>
      <a href ='/f/`+value.id+`/sub' class = 'filterbar-subscribe' data-filterid="`+value.id+`"> `
      console.log(UserHasFilter(value.id))
      if (UserHasFilter(value.id) == true) {
        console.log('minus')
        filterBarElement += '<span class="ti-minus"></span>'
      } else {
        console.log('plus')
        filterBarElement += '<span class="ti-plus"></span>'
      }
      filterBarElement +=`
      <a href ='/f/`+value.name+`' class='filterbar-link'>
        <span > `+value.name+`</span>
      </a>
    </ul>`;

    filterContainer.append(filterBarElement);
  })
  HookSubClick()
}

function AddFilterSearch(){

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
  $('.settings-link').click(function(e){
    var settingsMenu = $('.settings-menu')
    settingsMenu.toggle()
    settingsMenu.focus()
    settingsMenu.focusout(function(e){
      if ($(e.relatedTarget).parents('.settings-menu').length){

      } else {

        settingsMenu.hide()
      }
    })

    e.preventDefault();
  })
}

function GetFreshPost(){
  var newPost = newPosts.shift()

  if (newPost == undefined) {
    postIndex = postIndex + 100
    LoadNewPosts(postIndex,postIndex+100)
    newPost = newPosts.shift()
    if (newPost == undefined) {
      return
    }
  }

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

  $('.posts').append(newPost)
  console.log('done')
}



function AddTagVoteListener(){
  $(".upvote").click(function(e){
    e.preventDefault();
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())+1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/upvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
  $(".downvote").click(function(e){
    e.preventDefault();
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())-1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/downvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
}
