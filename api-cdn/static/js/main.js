
var $ = require('jquery');
require('jquery-ui')
require('selectize')

window.jQuery = $;
window.$ = $;

var site = require('./site');
var mySiteListener = new site();
var postHandler = require('./posthandler');
var myPostHandler = new postHandler;

$(function() {
  mySiteListener.load();
  myPostHandler.load();

});
