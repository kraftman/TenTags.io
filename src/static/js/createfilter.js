

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

  $('input#submitButton').click( function(e) {
    e.preventDefault();
    console.log($('form#createfilter').serialize());
    var requiredTags =  $("#requiredSelect").val()
    var bannedTags =  $("#bannedSelect").val()
    var form = {
      requiredTags: JSON.stringify(requiredTags),
      bannedTags: JSON.stringify(bannedTags),
      title: $('#filtertitle').val(),
      description: $('#filterdescription').val(),
      label: $('#filterlabel').val(),
    }
    $.ajax({
      type: "POST",
      url: '/filters/create',
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
