

$(function() {
  $(".chosen-select").chosen();

  $('#submitButton').click( function(e) {
    e.preventDefault();

    var selectedtags =  $(".chosen-select").val()
    var form = {
      selectedtags: JSON.stringify(selectedtags)
    }
    $.ajax({
      type: "POST",
      url: '/settings',
      data: form,
      success: function(data) {
           console.log(data);
         },
      dataType: 'json'
    });
  });
});
