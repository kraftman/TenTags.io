
var interact = require('interactjs');

var Mousetrap = require ('mousetrap')

var frontPage = function(userID, userSettings) {
  this.userID = userID;
  this.userSettings = userSettings
  this.newPosts = [];
  this.maxPosts = 10;
  this.seenPosts = [];
  this.postIndex = 10;
  this.hasFocus = false;
  console.log(userSettings);
};

frontPage.prototype = function(){
  var load = function(){
    addListeners.call(this);
    addToSeenPosts.call(this);
    loadKeybinds.call(this);
  },
  loadMorePosts = function(){
    var newPost = template.clone()

    var postInfo = GetFreshPost()
    if (postInfo == null) {
      console.log('no post')
      return
    }

    newPost.find('.postID').val(postInfo.id)
    newPost.find('.post-link').text(postInfo.title)

    var postLink;
    if (postInfo.link == null){
      postLink = '/p/'+postInfo.shortURL || postInfo.id
    } else {
      postLink = postInfo.link
    }

    if (postInfo.link == null && postInfo.bbID == null){

      newPost.find('.post-icon').attr('src','/static/icons/self.svg')
      newPost.find('.linkImg').hide()
    } else {
      newPost.find('.post-icon').attr('src','/icon/'+postInfo.id)
      newPost.find('.linkImg').attr('src','/icon/'+postInfo.id)
      console.log('adding '+postLink+ ' to linkImg parent')
      newPost.find('.linkImg').parent().attr('href',postLink);
      newPost.find('.linkImg').show()

    }

    if (postInfo.text) {
      newPost.find('.postelement-text').text(postInfo.text.substring(0, 300))
    }

    newPost.find('.post-link').attr('href','/p/'+postInfo.shortURL || postInfo.id);
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
  },
  getFreshPost = function(){
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
  },
  loadNewPosts = function(){
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
  },
  addToSeenPosts = function(){
    $.each($('#posts').children(), function(k,v) {
      var postID = $(v).find('.postID').val()
      seenPosts.push(postID)
    })
  },
  addListeners = function(){
    var context = this;
    $('.post-controls').hide();
    $( ".post" ).focus(function() {
      var postControls = $(this).find('.post-controls')
      $(postControls).show()
    });
    $( ".post" ).focusout(function() {
      var postControls = $(this).find('.post-controls')
      $(postControls).hide();
    });

    $('.post-save-button').click(function(e){
      e.preventDefault()
      e.stopPropagation()
      $(e.currentTarget).children().toggleClass('ti-star')
      $(e.currentTarget).children().toggleClass('ti-trash')


      var url = $(e.currentTarget).attr('href')

      $.get(url,function(data){
        console.log(data);
      })
    });

    $(".post-upvote, .upvoteButton").click(function(e) {
      e.preventDefault();
      $('.upvoteButton, .downvoteButton').hide();
      votePost.call(context, $(this).parents('.post'), 'up');
    })
    $(".post-downvote, .downvoteButton").click(function(e){
      e.preventDefault();
      $('.upvoteButton, .downvoteButton').hide();
      votePost.call(context, $(this).parents('.post'),'down');
    });
    if ($(window).width() < 769){
      interact('.post').draggable({
        inertia: true,
        onmove: function(e) { dragMoveListener.call(context, e) },
        onend: function(e) { onEndListener.call(context, e) },
        onstart: function(e) { onStartListener.call(context, e) },
        axis: 'x'
      })
    }

  },
  onStartListener = function(event){
    $(event.target).children('a').click(function(e){e.preventDefault()})
  },
  onEndListener = function(event){
    var target = event.target

    var x = (parseFloat(target.getAttribute('data-x')) || 0) + event.dx

    var context = this;

    $(event.target).children('a').off('click');
    var y = 0;

    event.preventDefault();
    console.log(event.dx)
    if ((event.dx<=0 && event.dx < -200)) {
      console.log('voting down')
      votePost.call(context, event.target,'down')
    } else if ((event.dx>0 && event.dx> 200)){
      console.log('voting up')
      votePost.call(context, event.target,'up')
    } else {

    }


    target.style.webkitTransform =
    target.style.transform =
    'translate(' + 0 + 'px, ' + y + 'px)';

    target.setAttribute('data-x', 0);
    target.setAttribute('data-y', 0);

  },

  upVotePost = function(e) {
    var context = this;
    var post = $(':focus')

      e.preventDefault()
    if (post.length) {
      votePost.call(context, post, 'up');
    }
  },

  downVotePost = function(e) {
    var post = $(':focus')
    var context = this;
    e.preventDefault()
    if (post.length) {
      console.log(2)
      votePost.call(context, post, 'down');
    }
  },


  votePost = function (post, direction){
    console.log('post:');
    console.log(post);
    //get the post
    var context = this;
    var postID = $(post).children('.postID').val()
    var postHash = $(post).children('.postHash').val()
    console.log(postID, postHash)

    if (context.userSettings.hideVotedPosts == true) {
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
      //console.log(data);
    })
  },
  openLink = function(e){
    if ($(':focus').find(".post-link").length) {
      var url = $(':focus').find(".post-link").attr('href')
      console.log(url)
      window.open(url, '_blank');
      e.preventDefault();
    }
  },

  openComments = function(e){
    if ($(':focus').find(".comment-link").length) {
      var url = document.location.origin+$(':focus').find(".comment-link").attr('href')
      console.log(url)
      window.open(url, '_blank');
      e.preventDefault();
    }
  },
  moveFocus = function(e){
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
  },

  loadKeybinds = function(){
    var context = this;
    Mousetrap.bind('up', moveFocus);
    Mousetrap.bind('down', moveFocus);
    Mousetrap.bind("enter", openLink)
    Mousetrap.bind('space', openComments);
    Mousetrap.bind("right", function(event) {upVotePost.call(context, event)})
    Mousetrap.bind("left", function(event) {downVotePost.call(context, event)})

    $('#posts').children().first().focus();
  },

  dragMoveListener = function(event){
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
  };

  return {
    load: load,
  }
}();

module.exports = frontPage;
