
function ConvertTagsToSelect(){



}

$(function() {

  ConvertTagsToSelect()





  /*
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
  */
});
