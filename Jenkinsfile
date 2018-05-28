pipeline {
  agent any
  stages {
    stage('error') {
      steps {
        sh '''echo \'hello world\'
touch filtta.env
./tentags buildtest
./tentags test'''
      }
    }
  }
}