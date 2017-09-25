

$(function() {

    $('#plustagselect').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
        create: function(input) {
          return {
              value: input,
              text: input
          }
      }});

      $('#minustagselect').selectize({
        plugins: ['remove_button'],
        delimiter: ' ',
        persist: false,
          create: function(input) {
            return {
                value: input,
                text: input
            }
        }});
});
