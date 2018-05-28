pipeline {
  agent {
    docker {
      image 'helloworld'
    }

  }
  stages {
    stage('') {
      steps {
        sh '''./tentags testbuild
./tentags test'''
      }
    }
  }
}