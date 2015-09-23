

$(function() {
  $(".chosen-select").chosen();

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
