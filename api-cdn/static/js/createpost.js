var knownFilters = [];

$(function() {

  $("#tagselect").chosen();
  $('#filterselect').chosen();
  AddPostFilterSearch()
  var tagSelectChosen = $('#tagselect_chosen')
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

  $('input#submitButton').click( function(e) {
    e.preventDefault();
    var selectedtags =  $(".chosen-select").val()
    var form = {
      selectedtags: JSON.stringify(selectedtags),
      title: $('#posttitle').val(),
      link: $('#postlink').val(),
      text: $('#posttext').val(),
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
});

function UpdateFilterSelect(filters){
  var filterContainer  = $('#filterselect')
  $.each(filters.data, function(index,filter){
    knownFilters.push(filter)
    filterContainer.append('<option value="'+filter.name+'">'+filter.name+'</option>');
    filterContainer.trigger("chosen:updated");
  })
}

function AddFilterToTags(e,p){
  if (p.selected){
    var filter = $.grep(knownFilters, function(n,i){
      console.log(n,i)
      return n.name == p.selected
    })[0]
    var tagSelectChosen = $('#tagselect')
    $.each(filter.requiredTags,function(k,v){
      console.log(k,v)
      tagSelectChosen.append('<option selected="selected" value="'+v.name+'">'+v.name+'</option>');
      tagSelectChosen.trigger("chosen:updated");
    })
  }
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
