
var $ = require('jquery');
var Mousetrap  = require('mousetrap');

var postHandler = function(userID, userSettings) {
  this.userID = userID;
  this.userSettings = userSettings;
  this.index = 0;
  this.hasFocus = false;
  this.currentParent = undefined;
};

postHandler.prototype = function() {

  var load = function(){
    addVoteTagListener.call(this);
    addListeners.call(this);
    addKeyboardListeners.call(this);
  }
  addListeners = function(){

    $(document).on('click', '.togglefiltercomment', function(e) {
      $(this).toggleClass('togglefilter-selected');
      var className = '.'+$(this).attr('data-filterID')
      console.log(className);
      $(className).toggle();
      e.preventDefault();
    });


    $('.comment-reply-button').click(function(e) {
      var parent = $(e.currentTarget).closest('.comment')

      $('#commentform').insertAfter(parent);
      $('#commentform').children('#parentID').val($(parent).data('commentid'))
      e.preventDefault();
      e.stopPropagation();
    })

    $('.post-comments').click(function(e){
      console.log('clicked')
      console.log(this)
      console.log(e.currentTarget)
      if ($(e.currentTarget).hasClass('post-comments')) {
          console.log('moving')
         $('#commentform').prependTo($(e.currentTarget))
         $('#commentform').children('#parentID').val($('#postID').val())
       } else {
         console.log('nooope')
       }
    })

    $('.upvotecomment-button, .downvotecomment-button').click(function(e){
      e.stopPropagation()
      console.log(e.currentTarget)
      e.preventDefault();
      console.log('/api'+$(e.currentTarget).attr('href'))
       $.get('/api'+$(e.currentTarget).attr('href'),function(data){
         console.log(data);
         if(data.error == false ){
           $(e.currentTarget).parent().children('.upvotecomment-button, .downvotecomment-button').hide()
         }
       })
    })

    $('.comment-collapse').click( function(e) {
      e.preventDefault();

      $(this).parent().find('.commentInfo').toggle()
      $(this).parent().find('.comment-title').toggle()

    })
  },
  changeFocus = function(value){
    console.log(this.index, value)
    if (this.index == -1) {
      this.index = 0
    } else {
      this.index = this.index + value;
    }
    var children = getChildComments(this.currentParent)
    var numChildren = children.length -1
    console.log(numChildren)
    this.index = Math.max(this.index, 0)
    this.index = Math.min(this.index, numChildren)
    children.eq(this.index).focus();


  },
  getChildComments = function(comment){
    return comment.children('.comment-body').eq(0).children('.commentInfo').eq(0).children('.comment')
  },
  addKeyboardListeners = function(){
    var context = this;
    Mousetrap.bind('tab', function(e) {
      e.preventDefault();
      console.log('tab pressed')
      context.currentParent = $('.post-comments')
      //getFirstChild(context.currentParent).focus()
      var children  = getChildComments(context.currentParent).eq(0).focus()
//      context.currentParent.children(".comment").eq(0).focus()

      if (context.hasFocus == true) {
        context.hasFocus = false
        //remove all binds
        Mousetrap.bind('up');
        Mousetrap.bind('down');
        Mousetrap.bind('right');
        Mousetrap.bind('left');
      } else {
        context.hasFocus = true
        Mousetrap.bind('up', function(e) {
          e.preventDefault();
          changeFocus.call(context,-1);
        });
        Mousetrap.bind('down', function(e) {
          e.preventDefault();
          changeFocus.call(context, 1);
        });
        Mousetrap.bind('left', function(e) {
          e.preventDefault();
          var children = getChildComments(context.currentParent.parents('.comment'));
          if (children.length) {
            context.currentParent = context.currentParent.parents('.comment')
            children.eq(0).focus()
            context.index = 0
          } else {
            context.currentParent = $('.post-comments')
            //getFirstChild(context.currentParent).focus()
            var children  = getChildComments(context.currentParent).eq(0).focus()
            context.index = 0
          }
        });
        Mousetrap.bind('right', function(e) {
          e.preventDefault();
          var newParent = getChildComments(context.currentParent).eq(context.index)
          var children = getChildComments(newParent)

          if (children.length) {
            console.log('newparent has children')
            context.currentParent = newParent;
            console.log(context.currentParent);
            children.eq(0).focus()
            context.index = 0
          } else {
            console.log('newparent has no childrens')
          }
          // if (context.currentParent.children(".comment").eq(this.index).length) {
          //   context.currentParent = context.currentParent.children(".comment").eq(this.index);
          //   context.index = 0
          //   context.currentParent.children(".comment").eq(0).focus()
          // }
        });
      }
    })
  }


  addVoteTagListener = function(){
    console.log('testing123')
    var context = this;
    $(".upvote-tag").click(function(e){
      e.preventDefault();
      var tagCount = $(this).parent().find('.tagcount')
      tagCount.text(Number(tagCount.text())+1)
      var tagID = $(this).parent().data('id')
      var postID = $('#postID').val()
      $.get('/post/upvotetag/'+tagID+'/'+postID,function(data){
        console.log(data);
      })
    })
    $(".downvote-tag").click(function(e){
      e.preventDefault();
      var tagCount = $(this).parent().find('.tagcount')
      tagCount.text(Number(tagCount.text())-1)
      var tagID = $(this).parent().data('id')
      var postID = $('#postID').val()
      $.get('/post/downvotetag/'+tagID+'/'+postID,function(data){
        console.log(data);
      })
    })
  };
  return {
    load: load,
  };
}();

module.exports = postHandler;
