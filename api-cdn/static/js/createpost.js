var knownFilters = [];

$(function() {

  $("#tagselect").chosen();
  $('#filterselect').chosen();
  AddPostFilterSearch()
  ConvertTagsToSelect();
  OverrideSubmit();
  var tagSelectChosen = $('#tagselect')
  tagSelectChosen.bind('keyup',function(e) {
    if(e.which === 13 || e.which === 32) {
      var newItem = $(e.target).val();
      var mySelect = $(".chosen-select option[value='"+newItem+"']");
      if (mySelect.length == 0) {
        tagSelectChosen.append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
        tagSelectChosen.trigger("chosen:updated");
      }
    }
  });
});


//<option name='option["<%= i -%>"]' value = "<%= tag.name -%>"><%= tag.name -%></option>
function ConvertTagsToSelect(){
  console.log('this')
  $('#selectedtags').replaceWith(`<select name='tagselect' id='selectedtags' style="width:350px;" multiple='true' class="chosen-select" data-placeholder='Add tags'>
      </select>`)
  $('#selectedtags').chosen()
  $('#selectedtags_chosen').bind('keyup',function(e) {

    console.log($(e.target).val())
    var test = $(e.target).val()
    $.getJSON('/api/tags/'+$(e.target).val(),function(data){
      if (data.status == 'success'){
        console.log(data)
        $.each(data.data, function(k,v){
          $('#selectedtags').append('<option value="'+v+'">'+v+'</option>');
          $('#selectedtags').trigger("chosen:updated");
          $(e.target).val(test)
        })
      }
    })
  })

}

function OverrideSubmit(){
  $('input#submitButton').click( function(e) {
    e.preventDefault();
    var selectedtags =  $("#tagselect").val()
    var form = {
      selectedtags: JSON.stringify(selectedtags),
      posttitle: $('#posttitle').val(),
      postlink: $('#postlink').val(),
      posttext: $('#posttext').val(),
    }
    $.ajax({
      type: "POST",
      url: '/post/new',
      data: form,
      success: function(data) {
        console.log('this '+data)
        console.log(data)
        if (data.id) {
          window.location.assign('/post/'+data.id);
        }
        $('#submitError').html(data);
      },
      error: function(data) {
        console.log('that');
        console.log(data.responseText);
      },
      dataType: 'json'
    });
  });
}

function UpdateFilterSelect(filters){
  var filterContainer  = $('#filterselect')
  $.each(filters.data, function(index,filter){
    knownFilters.push(filter)
    filterContainer.append('<option value="'+filter.name+'">'+filter.name+'</option>');
    filterContainer.trigger("chosen:updated");
  })
}

function AddFilterToTags(e,p){

  var selectedFilter = $.grep(knownFilters, function(n,i){
    console.log(n,i)
    return n.name == p.selected
  })[0]

  if (p.selected){
    var tagSelectChosen = $('#tagselect')
    $.each(selectedFilter.requiredTagNames,function(k,v){
      console.log(k,v)
      tagSelectChosen.append('<option selected="selected" value="'+v+'">'+v+'</option>');
      tagSelectChosen.trigger("chosen:updated");
    })
  }

  //update all the other filters
  $.each($('#filterselect_chosen').find('li.search-choice'), function(k,filterElement){
    var filterName = $(filterElement).find('span').text()
    var filter = $.grep(knownFilters, function(n,i){
      console.log(n,i)
      return n.name == filterName
    })[0]

    var foundBannedTag;

    $.each($('#tagselect_chosen').find('li.search-choice'), function(k,tagElement) {
      var tagName = $(tagElement).find('span').text()
      var found;
      $.each(filter.bannedTagNames, function(k,v){
        if (v == tagName){
          found = true;
        }
      })
      if (found == true) {
        foundBannedTag = true
        console.log('test')
        $(tagElement).addClass('banned');
      } else {
        $(tagElement).removeClass('banned');
      }
    })

    if (foundBannedTag == true){
      console.log('marking filter as banned')
      $(filterElement).addClass('banned');
    } else {
      $(filterElement).removeClass('banned');
    }

  })

}

function AddPostFilterSearch(){

  $('#filterselect').change(AddFilterToTags);

  $('#filterselect_chosen').find('input').on('input', function() {

    clearTimeout($(this).data('timeout'));
    var _self = this;
    $(this).data('timeout', setTimeout(function () {
      console.log('searching')

      if (_self.value.trim()){
        $.get('/api/filter/search/'+_self.value+'?withTags=true', {
            search: _self.value
        }, UpdateFilterSelect);
      }
    }, 200));
  })
}
