pipeline {
  agent any
  stages {
    stage('error') {
      steps {
        sh '''echo \'hello world\'
pwd

./tentags buildtest'''
      }
    }
  }
}