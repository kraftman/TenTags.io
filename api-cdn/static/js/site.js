

// all the base site js for the sidebar, topbar, etc


var $ = require('jquery');
var Mousetrap = require ('mousetrap')

var TagVoteListener = function() {
  this.userID = $('#userID').val()
};

TagVoteListener.prototype = function() {

  var load = function(){
    addVoteTagListener.call(this);
    addMenuListener.call(this);
    addFilterSearchListener.call(this);
    getUserSettings.call(this);
  },
  getUserSettings = function(){
    var context = this
    if (!context.userID) {
      return;
    }
    $.getJSON('/api/user/'+context.userID+'/settings',function(data){

      if (data.status == 'success'){
        context.userSettings = data.data
      }
    })
  }

  addMenuListener = function() {
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
  },
  addFilterSearchListener = function(){

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
  },
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
  };

  return {
    load: load,
  };
}();

module.exports = TagVoteListener;
