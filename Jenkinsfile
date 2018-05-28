pipeline {
  agent none
  stages {
    stage('error') {
      steps {
        sh '''sh tentags testbuild
sh tentags test'''
      }
    }
  }
}