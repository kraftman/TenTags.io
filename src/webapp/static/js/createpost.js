

$(function() {
  $(".chosen-select").chosen();

  $('input#submitButton').click( function(e) {
    e.preventDefault();
    console.log($('form#createpost').serialize());
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
         },
      dataType: 'json'
    });
  });
});
