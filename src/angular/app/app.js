'use strict';

var myApp = angular.module('myApp', [
  'ui.router',
  'myApp.version'
]);

myApp.config(function($stateProvider, $urlRouterProvider) {
  $urlRouterProvider.otherwise('/');

  $stateProvider
    .state('home',{
        url: '/',
        views: {
            'header': {
                templateUrl: 'templates/partials/header.html'
            },
            'filterbar': {
                templateUrl: 'templates/partials/filterbar.html',
                controller: 'FilterBarController'
            },
            'content': {
                templateUrl: 'templates/partials/content.html'
            }
        }
    })
    .state('home.filters',{
        url: 'f/:subname',
        views: {
          'content@': {
              templateUrl: 'templates/partials/content2.html',
              controller: 'FilterController'
          }
        }
    })
});

myApp.controller('FilterController', ['$scope','$stateParams', function($scope,$stateParams) {
  $scope.subname = $stateParams.subname;

}]);

myApp.controller('FilterBarController',function($scope,$http) {
  $http.get('/static/defaultsubs.json').success(function(data) {
    $scope.subs = data;
  });
});

myApp.controller('ContentController',function($scope,$http) {
  $http.get('/static/defaultsubs.json').success(function(data) {
    $scope.subs = data;
  });
})
