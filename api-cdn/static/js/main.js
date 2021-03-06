
var $ = require('jquery');
require('jquery-ui');
require('jquery-ui-sortable');
window.jQuery = $;
window.$ = $;

var site = require('./site');
var postHandler = require('./posthandler');
var sideBar = require('./sidebar');
var frontPage = require ('./frontpage');
var createPost = require('./createpost');
var createFilter = require('./createfilter');

function SubmitLogin(e){
  console.log('done')
  document.getElementById("register").submit();
}


window.SubmitLogin = SubmitLogin;

$(function() {
  var userID = $('#userID').val()
  var userSettings;

  function loadModules(){


    (new site(userID, userSettings)).load();
    (new postHandler(userID, userSettings)).load();
    (new sideBar(userID, userSettings)).load();
    (new frontPage(userID, userSettings)).load();
    (new createPost(userID, userSettings)).load();
    (new createFilter(userID, userSettings)).load();
  }

  if (userID != 'nil') {

    $.getJSON('/api/user/'+userID+'/settings',function(data){
      userSettings = data.data;
      loadModules();

    })
  } else {
    loadModules();
  }

});
