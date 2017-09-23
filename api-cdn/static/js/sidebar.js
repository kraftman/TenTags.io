
var $ = require('jquery');


var postHandler = function(userID) {
  this.userID = userID
};

postHandler.prototype = function() {

    var load = function(){
      loadUserFilters.call(this);
      addFilterToggle.call(this);
      addFilterSearchListener.call(this);
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
        console.log('toggling filters');
        $('.filter-styles').toggle()
        e.preventDefault();
      })

    },


    loadUserFilters = function(){
      var context = this
      if (!this.userID) {
        console.log('couldnt get userID')
        return;
      }

      $.get('/api/user/filters', function(data){
        if(data.error == false) {
          context.userFilters = data.data
        }
      });
    },

    userHasFilter = function(filterID){
      var found = null;
      $.each(this.userFilters, function(k,v){

        if (v.id == filterID) {
          found = true;
          return;
        }

      })
      return found;
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


    updateSidebar = function(filters){
      var filterContainer  = $('.filterbar-results')
      filterContainer.empty()
      $.each(filters.data, function(index,value){


        //filterContainer.append(
        var filterBarElement = `
        <ul class = 'filterbarelement'>
          <a href ='/f/`+value.id+`/sub' class = 'filterbar-subscribe' data-filterid="`+value.id+`"> `

          if (userHasFilter.call(this,value.id) == true) {
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
      hookSubClick()
    }


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
            }, updateSidebar);
          } else {
            $.get('/api/user/filters', {
                search: _self.value
            }, updateSidebar);
          }
        }, 200));
      })

    };


    return {
      load: load,
    };
  }();

  module.exports = postHandler;
