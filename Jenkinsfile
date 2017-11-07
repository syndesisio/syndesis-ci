/**
 This pipeline builds the whole Syndesis CI:

 - Jenkins Plugins
 - Jenkins Agent Images
 - Jenkins Images (Openshift and Syndesis)
 **/
def currentNamespace='syndesis-ci'

node {
  stage ('Load pipeline library') {
    checkout scm
    sh "ls -al ${WORKSPACE}/pipeline-library/"
    library identifier: "local-pipeline-library@${env.BRANCH_NAME}", retriever: workspaceRetriever("${WORKSPACE}/pipeline-library/")
    currentNamespace=podNamespace()
  }

  inNamespace(cloud: 'openshift', prefix: 'ci-self-test') {
    echo "Using ${KUBERNETES_NAMESPACE}"
    uberPod {
      inside(serviceAccount: 'jenkins', namespace: "$currentNamespace") {
        stage ('Checkout source') {
          //Checkout the source again inside the agent...
          checkout scm
          sh 'git submodule update --init --recursive'
        }

        stage('Build') {
          sh 'oc version'
          //We disable test, because some plugins assume minikube and break ...
          sh "./bin/build.sh --artifact-prefix test- --skip-tests --namespace $KUBERNETES_NAMESPACE"
        }
      }
    }
  }
}
