pipeline {
  agent none
  stages {
    stage('error') {
      steps {
        sh '''./tentags testbuild
./tentags test'''
      }
    }
  }
}