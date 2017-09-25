

var selectize = require('selectize');

var createfilter = function(userID, userSettings){
  this.userID = userID;
  this.userSettings = userSettings;
}

createfilter.prototype = function(){
  var load = function(){
    addSelectize.call(this);
  },
  addSelectize = function(){
    $('#requiredTagNames').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
        create: function(input) {
          return {
              value: input,
              text: input
          }
      }});

    $('#bannedTagNames').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
        create: function(input) {
          return {
              value: input,
              text: input
          }
      }});
  };



  return {
    load: load,
  };
}();


module.exports = createfilter;
