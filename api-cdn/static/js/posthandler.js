
var $ = require('jquery');

var postHandler = function(userID, userSettings) {
  this.userID = userID;
  this.userSettings = userSettings;
};

postHandler.prototype = function() {

  var load = function(){
    //addVoteTagListener.call(this);
  };

  // addVoteTagListener = function(){
  //   console.log('testing123')
  //   var context = this;
  //   $(".upvote").click(function(e){
  //     e.preventDefault();
  //     var tagCount = $(this).parent().find('.tagcount')
  //     tagCount.text(Number(tagCount.text())+1)
  //     var tagID = $(this).parent().data('id')
  //     var postID = $('#postID').val()
  //     $.get('/post/upvotetag/'+tagID+'/'+postID,function(data){
  //       console.log(data);
  //     })
  //   })
  //   $(".downvote").click(function(e){
  //     e.preventDefault();
  //     var tagCount = $(this).parent().find('.tagcount')
  //     tagCount.text(Number(tagCount.text())-1)
  //     var tagID = $(this).parent().data('id')
  //     var postID = $('#postID').val()
  //     $.get('/post/downvotetag/'+tagID+'/'+postID,function(data){
  //       console.log(data);
  //     })
  //   })
  // },






  return {
    load: load,
  };
}();

module.exports = postHandler;
