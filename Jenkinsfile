pipeline {
  agent any
  stages {
    stage('build docker') {
      steps {
        sh '''echo \'buildsingss\'
touch filtta.env
./tentags buildtest
./tentags test'''
      }
    }
    stage('publish coverage') {
      steps {
        cobertura(autoUpdateHealth: true, autoUpdateStability: true, coberturaReportFile: 'api-cdn/luacov.reports.out', failNoReports: true)
      }  
    }
  }
  post {
    always {
      archive 'api-cdn/**/test.xml',
      junit 'api-cdn/**/test.xml'

    }

  }
}