pipeline {
  agent any
  stages {
    stage('build docker') {
      steps {
        sh '''
touch filtta.env
./tentags buildtest
./tentags test'''
      }
    }
    stage('publish coverage') {
      steps {
        cobertura(autoUpdateHealth: true, autoUpdateStability: true, coberturaReportFile: 'api-cdn/luacov.report.out', failNoReports: true)
      }
    }
  }
}