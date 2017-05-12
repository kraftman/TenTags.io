

$(function() {

    $('#requiredSelect').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
        create: function(input) {
          return {
              value: input,
              text: input
          }
      }});

      $('#bannedSelect').selectize({
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
