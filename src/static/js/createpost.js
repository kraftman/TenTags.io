

$(function() {
  $(".chosen-select").chosen();
  $(".chosen-container").bind('keyup',function(e) {
    if(e.which === 13 || e.which === 32) {

      var newItem = $(e.target).val();
      var mySelect = $(".chosen-select option[value='"+newItem+"']");
      if (mySelect.length == 0) {
        $(".chosen-select").append('<option selected="selected" value="'+newItem+'">'+newItem+'</option>');
        $(".chosen-select").trigger("chosen:updated");
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
        console.log(data);
        window.location.replace('/post/'+data.id);
      },
      error: function(data) {
        console.log(data.responseText);
      },
      dataType: 'json'
    });
  });
});
