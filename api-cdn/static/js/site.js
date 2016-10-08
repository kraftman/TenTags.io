$(function() {
  AddVoteListener();
  AddMenuHandler();
  AddFilterSearch();
})

var userFilters = {};

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
  $('#filterSearch').on('input', function() {
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

function AddVoteListener(){
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
