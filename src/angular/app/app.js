'use strict';

var myApp = angular.module('myApp', [
  'ui.router',
  'myApp.version',
  'ngMaterial'
]);

myApp.config(function($stateProvider, $urlRouterProvider,$mdThemingProvider) {
  $urlRouterProvider.otherwise('/');

  $mdThemingProvider.theme('default')
      .primaryPalette('green')
      .accentPalette('red');

  $stateProvider
    .state('home',{
        url: '/',
        views: {
            'filterbar': {
                templateUrl: 'templates/partials/filterbar.html',
                controller: 'FilterBarController'
            },
            'content': {
                templateUrl: 'templates/partials/content.html',
                controller: 'FilterController'
            }
        }
    })
    .state('home.filters',{
        url: 'f/:subname',
        views: {
          'content@': {
              templateUrl: 'templates/partials/content.html',
              controller: 'FilterController'
          }
        }
    })
});

myApp.controller('FilterController', ['$scope','$stateParams','$http', function($scope,$stateParams,$http) {
  if (typeof($stateParams.subname) !== 'undefined') {
    $scope.subname = $stateParams.subname;
  } else {
    $scope.subname = 'default';
  };
  $http.get('/static/'+$scope.subname+'.json').success(function(data) {
    $scope.posts = data;
  });

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
