

$(function() {
  $(".chosen-select").chosen();
  $("#requiredSelect_chosen").bind('keyup',function(e) {
    if(e.which === 13 || e.which === 32) {

      var newItem = $(e.target).val();
      console.log(e.target)
      var mySelect = $("#requiredSelect option[value='"+newItem+"']");
      if (mySelect.length == 0) {
        $("#requiredSelect").append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
        $("#requiredSelect").trigger("chosen:updated");
      }
    }
});
$("#bannedSelect_chosen").bind('keyup',function(e) {
  if(e.which === 13 || e.which === 32) {

    var newItem = $(e.target).val();
    console.log(e.target)
    var mySelect = $("#bannedSelect option[value='"+newItem+"']");
    if (mySelect.length == 0) {
      $("#bannedSelect").append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
      $("#bannedSelect").trigger("chosen:updated");
    }
  }
});

  $('#updateTagsButton').click( function(e) {
    e.preventDefault();
    console.log($('form#createfilter').serialize());
    var requiredTagIDs =  $("#requiredSelect").val()
    var bannedTagIDs =  $("#bannedSelect").val()
    var form = {
      requiredTagIDs: JSON.stringify(requiredTagIDs),
      bannedTagIDs: JSON.stringify(bannedTagIDs),
    }
    console.log($('#hiddenFilterName').val());
    $.ajax({
      type: "POST",
      url: '/filters/'+$('#hiddenFilterName').val(),
      data: form,
      success: function(data) {
           console.log(data);
         },
      error: function(data) {
        console.log(data.responseText);
      },
      dataType: 'json'
    });
  });
});
