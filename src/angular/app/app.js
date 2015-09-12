'use strict';

// Declare app level module which depends on views, and components
angular.module('myApp', [
  'ui.router',
  'myApp.version'
]).
config(function($stateProvider, $urlRouterProvider) {
  $urlRouterProvider.otherwise('/');

  $stateProvider
    .state('home',{
        url: '/',
        views: {
            'header': {
                templateUrl: 'templates/partials/header.html'
            },
            'sidebar': {
                templateUrl: 'templates/partials/sidebar.html'
            },
            'content': {
                templateUrl: 'templates/partials/content.html'
            }
        }
    })
});
