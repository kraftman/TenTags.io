
function ConvertTagsToSelect(){
  $('#requiredTagNames').replaceWith(`<select name='requiredTagNames' id='requiredTagNames' style="width:350px;" multiple='true' class="chosen-select" data-placeholder='Add tags'>
      </select>`)
  $('#requiredTagNames').chosen()

  $('#bannedTagNames').replaceWith(`<select name='bannedTagNames' id='bannedTagNames' style="width:350px;" multiple='true' class="chosen-select" data-placeholder='Add tags'>
      </select>`)
  $('#bannedTagNames').chosen()

  $("#requiredTagNames_chosen").bind('keyup',function(e) {
    if(e.which === 13 || e.which === 32) {

      var newItem = $(e.target).val();
      console.log(e.target)
      var mySelect = $("#requiredTagNames option[value='"+newItem+"']");
      if (mySelect.length == 0) {
        $("#requiredTagNames").append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
        $("#requiredTagNames").trigger("chosen:updated");
      }
    }
  });

  $("#bannedTagNames_chosen").bind('keyup',function(e) {
    if(e.which === 13 || e.which === 32) {

      var newItem = $(e.target).val();
      console.log(e.target)
      var mySelect = $("#bannedTagNames option[value='"+newItem+"']");
      if (mySelect.length == 0) {
        $("#bannedTagNames").append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
        $("#bannedTagNames").trigger("chosen:updated");
      }
    }
  });

}

$(function() {

  ConvertTagsToSelect()






  $('input#submitButton').click( function(e) {
    e.preventDefault();
    console.log($('form#createfilter').serialize());
    var requiredTagNames =  $("#requiredTagNames").val()
    var bannedTagNames =  $("#bannedTagNames").val()
    var form = {
      requiredTagNames: JSON.stringify(requiredTagNames),
      bannedTagNames: JSON.stringify(bannedTagNames),
      title: $('#filtertitle').val(),
      description: $('#filterdescription').val(),
      name: $('#filterName').val(),
    }
    $.ajax({
      type: "POST",
      url: '/api/filters/create',
      data: form,
      success: function(data) {
        if (data.status == 'success'){
          console.log('redirecting')
          window.location.replace('/');
        } else {
          $('.warningText').text(data.error)
          console.log('failed: '+data.error)
        }
      },
      error: function(data) {
        console.log('failed');
        console.log(data);
      },
      dataType: 'json'
    });
  });
});
