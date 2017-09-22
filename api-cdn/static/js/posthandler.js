
var $ = require('jquery');
var Mousetrap = require ('mousetrap')

var postHandler = function() {
  this.userID = $('#userID').val()
};

postHandler.prototype = function() {

  var load = function(){
    addVoteTagListener.call(this);
    loadKeybinds.call(this);
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
  }
  addVoteTagListener = function(){
    console.log('testing123')
    var context = this;
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
  loadKeybinds = function(){
    var context = this;
    Mousetrap.bind('up', moveFocus.call(context));
    Mousetrap.bind('down', moveFocus.call(context));
    Mousetrap.bind("enter", OpenLink)
    Mousetrap.bind('space', OpenComments);
    Mousetrap.bind("right", Upvote)
    Mousetrap.bind("left", Downvote)

    $('#posts').children().first().focus();
  },

  upVotePost = function(e) {
    var post = $(':focus')

      e.preventDefault()
    if (post.length) {
      VotePost(post, 'up');
    }
  },

  downVotePost = function(e) {
    var post = $(':focus')

    e.preventDefault()
    if (post.length) {
      console.log(2)
      VotePost(post, 'down');
    }
  },

  votePost = function (post, direction){

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
      //console.log(data);
    })
  };



  return {
    load: load,
  };
}();

module.exports = postHandler;
