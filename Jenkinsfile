node {

  checkout scm
  stage ('Update submodules') {
    sh 'git submodule update --init --recursive'
  }

  stage ('Load pipeline library') {
    library identifier: "syndesis-pipeline-library@${env.BRANCH_NAME}", retriever: workspaceRetriever("${WORKSPACE}/pipeline-library")
  }

  inNamespace(cloud: 'openshift', prefix: 'ci-self-test') {
    echo "Using ${KUBERNETES_NAMESPACE}"
    slave {
      withOpenshift {
        inside(namespace: "${KUBERNETES_NAMESPACE}") {
          container('openshift') {
            sh './bin/build.sh --artifact-prefix test-'
          }
        }
      }
    }
  }
}
