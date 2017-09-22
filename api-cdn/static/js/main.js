
var $ = require('jquery');
require('jquery-ui')
require('selectize')
window.jQuery = $;
window.$ = $;

var site = require('./site');
var mySiteListener = new site();

$(function() {
  mySiteListener.load();

});
