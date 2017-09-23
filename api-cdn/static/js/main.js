
var $ = require('jquery');
require('jquery-ui')
require('selectize')

window.jQuery = $;
window.$ = $;

var site = require('./site');
var postHandler = require('./posthandler');
var sideBar = require('./sidebar');
var frontPage = require ('./frontpage');

function SubmitLogin(e){
  console.log(e)
}
window.SubmitLogin = SubmitLogin;

$(function() {
  var userID = $('#userID').val()


  $.getJSON('/api/user/'+userID+'/settings',function(data){

    var userSettings = data.data;
    (new site(userID, userSettings)).load();
    (new postHandler(userID, userSettings)).load();
    (new sideBar(userID, userSettings)).load();
    (new frontPage(userID, userSettings)).load();

  })


});
