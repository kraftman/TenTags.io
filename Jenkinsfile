pipeline {
  agent any
  stages {
    stage('build docker') {
      steps {
        sh '''echo \'hello world\'
touch filtta.env
./tentags buildtest
./tentags test'''
      }
    }
    stage('publish coverage') {
      steps {
        cobertura(autoUpdateHealth: true, autoUpdateStability: true, coberturaReportFile: 'api-cdn/luacov.stats.out', failNoReports: true)
      }
    }
  }
}