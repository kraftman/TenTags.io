

var userSettings = {};
var userID;
var userFilters = [];

$(function() {



  //$('.settings-menu').focusout(function(){
  //  $('.settings-menu').hide()
  //})
})



// function SubmitLogin(){
//
//   console.log('done')
//   document.getElementById("register").submit();
// }





// function ChangeFocus(value) {
//
//   index = index + value;
//   var numChildren = $('#posts').children().length -1
//   index = Math.max(index, 0)
//   index = Math.min(index, numChildren)
//   $('#posts').children().eq(index).focus();
// }

function UserHasFilter(filterID){
  var found = null;
  $.each(userFilters, function(k,v){

    if (v.id == filterID) {
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
