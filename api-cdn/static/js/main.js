
var $ = require('jquery');
require('jquery-ui')
require('selectize')

window.jQuery = $;
window.$ = $;

var site = require('./site');
var postHandler = require('./posthandler');
var sideBar = require('./sidebar');
var frontPage = require ('./frontpage');
var validate = require('validate.js');

function SubmitLogin(e){
  console.log('done')
  document.getElementById("register").submit();
}


window.SubmitLogin = SubmitLogin;

$(function() {
  var userID = $('#userID').val()

  $('.form-login').submit(function(e){
    e.preventDefault()
    var email = $('.register-box').val().replace(' ', '')
    if (!email) {
      window.location.replace('/login');
    };
    var constraints = {
      from: {
        email: true
      }
    };


    var isInvalid = validate({from: email}, constraints);
    if (isInvalid) {
      window.alert('Invalid email!');
      return false;
    }
    grecaptcha.execute();


    return false;
  });


  $.getJSON('/api/user/'+userID+'/settings',function(data){

    var userSettings = data.data;
    (new site(userID, userSettings)).load();
    (new postHandler(userID, userSettings)).load();
    (new sideBar(userID, userSettings)).load();
    (new frontPage(userID, userSettings)).load();

  })


});
