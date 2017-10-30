/**
   This pipeline builds the whole Syndesis CI:

 - Jenkins Plugins
 - Jenkins Agent Images
 - Jenkins Images (Openshift and Syndesis)
 **/
node {
  stage ('Load pipeline library') {
    checkout scm
    sh 'git submodule update --init pipeline-library'
    library identifier: "syndesis-pipeline-library@${env.BRANCH_NAME}", retriever: workspaceRetriever("${WORKSPACE}/pipeline-library")
  }

  inNamespace(cloud: 'openshift', prefix: 'ci-self-test') {
    echo "Using ${KUBERNETES_NAMESPACE}"
    slave {
      inside(serviceAccount: 'jenkins') {
        stage ('Checkout source') {
          //Checkout the source again inside the agent...
          checkout scm
          sh 'git submodule update --init --recursive'
        }

        stage('Build') {
          //We disable test, because some plugins assume minikube and break ...
          sh "./bin/build.sh --artifact-prefix test- --skip-tests --namespace $KUBERNETES_NAMESPACE"
        }
      }
    }
  }
}
