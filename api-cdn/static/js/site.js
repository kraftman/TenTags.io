

// all the base site js for the sidebar, topbar, etc


var $ = require('jquery');

var TagVoteListener = function() {
  this.userID = $('#userID').val()
};

TagVoteListener.prototype = function() {

  var load = function(){
    addMenuListener.call(this);
    addFilterSearchListener.call(this);
    getUserSettings.call(this);
    loadUserFilters.call(this);
    addInfoBar.call(this);
    hideRecapchta.call(this);
    addFilterToggle.call(this);
    hookSubClick.call(this);
    randomCrap.call(this);
  },
  randomCrap = function() {
    $('.post-full-topbar').click(function(e){
      console.log(e.currentTarget)
      $(e.currentTarget).parent().find('.linkImg').toggle()
    })

    $('.post').hover(function(e){
      $(e.target).children('.post-full-bottombar').show();
      //$(e.target).find('.post-filters').show();
    })

    $('.post').focusout(function(e){
      $(e.target).children('.post-full-bottombar').hide();
      //$(e.target).find('.post-filters').hide();
    })
  },
  hookSubClick = function(){
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
  },
  addFilterToggle = function(){
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
  },

  loadUserFilters = function(){
    var context = this
    if (!this.userID) {
      console.log('couldnt get userID')
      return;
    }

    $.get('/api/user/filters', function(data){
      console.log(data)
      if(data.error == false) {
        this.userFilters = data.data
      }
    });
  },
  addInfoBar = function(){
    $('.infobar-title').click(function(e){
      $('.infobar-body').toggle()
      e.preventDefault()
    })
  },
  hideRecapchta = function() {
    $('.form-login').focusin(function(){
      $('.form-login > div').show()
    })

    $('.form-login').focusout(function(){
      $('.form-login > div').hide();
    })

    $('.g-recaptcha').prop('disabled',true)
  },



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
  };


  return {
    load: load,
  };
}();

module.exports = TagVoteListener;
