#!/bin/bash

# Exit if any error occurs
set -e

#
# Display a help message.
function displayHelp() {
  echo "This script helps you build the syndesis monorepo."
  echo "The available options are:"
  echo " --skip-tests            Skips the test execution."
  echo " --skip-image-builds     Skips image builds."
  echo " --with-image-streams    Builds everything using image streams."
  echo " --namespace N           Specifies the namespace to use."
  echo " --resume-from           Resume build from module."
  echo " --version V             Use an actual version instead of SNAPSHOT(s) and latest(s)."
  echo " --clean                 Cleans up the projects."
  echo " --help                  Displays this help message."
}

#
# Aliases
pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

#
# Checks if a flag is present in the arguments.
function hasflag() {
  filter=$1
  for var in "${@:2}"; do
    if [ "$var" = "$filter" ]; then
      echo 'true'
      break;
    fi
  done
}

#
# Read the value of an option.
function readopt() {
  filter=$1
  next=false
  for var in "${@:2}"; do
    if $next; then
      echo $var
      break;
    fi
    if [ "$var" = "$filter" ]; then
      next=true
    fi
  done
}

# Copy plugin
function copyplugin() {
  PLUGIN=$1
  SOURCE_DIR=${2:-"../../plugins/$PLUGIN-plugin/target/"}
  TARGET_DIR=${3:-"plugins"}
  if [ -f $SOURCE_DIR/$PLUGIN.hpi ]; then
    cp $SOURCE_DIR/$PLUGIN.hpi $TARGET_DIR/$PLUGIN.jpi
  fi
}

function createbc() {
  DOCKERFILE=$1
  IMAGESTREAM=$2
  BUILD_CONFIG=`oc get bc | grep $IMAGESTREAM || echo ""`
  if [ -z "$BUILD_CONFIG" ]; then
    echo "Creating Build Conifg: $IMAGESTREAM"
    cat $DOCKERFILE | oc new-build --dockerfile=- --to=syndesis/$IMAGESTREAM:latest --strategy=docker || true

    # Verify that the build config has been created.
    BUILD_CONFIG=`oc get bc | grep $IMAGESTREAM || echo ""`
    if [ -z "$BUILD_CONFIG" ]; then
      echo "Failed to create Build Config: $IMAGESTREAM"
      exit 1
    fi
  fi
}

function istag2docker() {
  ISTAG=$1
  oc get istag | grep $ISTAG | awk -F " " '{print $2}'
}

function images() {
 pushd images

  # Openshift Jenkins
  pushd openshift-jenkins/2
  createbc Dockerfile openshift-jenkins
  tar -cvf archive.tar .
  oc start-build openshift-jenkins --from-archive=archive.tar --follow
  popd

  # Syndesis Jenkins
  pushd syndesis-jenkins
  # Let's copy the plugins
  copyplugin kubernetes
  copyplugin durable-task-plugin
  copyplugin workflow-cps-global-lib
  # This is a multimodule project so it does get a little bit more complicated
  copyplugin kubernetes-pipeline-arquillian-steps ../../plugins/kubernetes-pipeline-plugin/arquillian-steps/target/
  OPENSHIFT_JENKINS_DOCKER_IMAGE=$(istag2docker openshift-jenkins)
  oc new-build --binary=true --docker-image=$OPENSHIFT_JENKINS_DOCKER_IMAGE --to=syndesis/syndesis-jenkins:latest --strategy=source || true
  tar -cvf archive.tar bin configuration plugins plugins.txt
  oc start-build syndesis-jenkins --from-archive=archive.tar --follow
  popd

  popd
}

function agentimages() {
 pushd images/openshift-jenkins

  #
  # Jenkins Agents
  pushd slave-base
  createbc Dockerfile jenkins-slave-base-centos7
  tar -cvf archive.tar .
  oc start-build jenkins-slave-base-centos7 --from-archive=archive.tar --follow
  popd

  pushd slave-nodejs
  createbc Dockerfile jenkins-slave-nodejs-centos7
  tar -cvf archive.tar .
  oc start-build jenkins-slave-nodejs-centos7 --from-archive=archive.tar --follow
  popd

  pushd slave-maven
  createbc Dockerfile jenkins-slave-maven-centos7
  tar -cvf archive.tar .
  oc start-build jenkins-slave-maven-centos7 --from-archive=archive.tar --follow
  popd

  popd
}

function plugins() {
  pushd plugins
  #Kubernetes Plugin
  pushd kubernetes-plugin
  mvn clean install $MAVEN_OPTS
  popd

  #Kubernetes Pipeline Plugin
  pushd kubernetes-pipeline-plugin
  mvn clean install $MAVEN_OPTS
  popd

  #Durable Task Plugin
  pushd durable-task-plugin
  mvn clean install $MAVEN_OPTS
  popd

  #Groovy Pipeline Libraries
  pushd workflow-cps-global-lib-plugin
  mvn clean install $MAVEN_OPTS
  popd

  popd
}

function modules_to_build() {
  modules="plugins agentimages images"
  if [ "x${RF}" != x ]; then
    modules=$(echo $modules | sed -e "s/^.*$RF/$RF/")
  fi
  echo $modules
}

#
# Options and flags
SKIP_TESTS=$(hasflag --skip-tests "$@" 2> /dev/null)
SKIP_IMAGE_BUILDS=$(hasflag --skip-image-builds "$@" 2> /dev/null)
CLEAN=$(hasflag --clean "$@" 2> /dev/null)
WITH_IMAGE_STREAMS=$(hasflag --with-image-streams "$@" 2> /dev/null)

NAMESPACE=$(readopt --namespace "$@" 2> /dev/null)

RESUME_FROM=$(readopt --resume-from "$@" 2> /dev/null)
HELP=$(hasflag --help "$@" 2> /dev/null)

if [ -n "$HELP" ]; then
  displayHelp
  exit 0
fi

#
# Internal variable default values
OC_OPTS=""
MAVEN_OPTS=""
MAVEN_CLEAN_GOAL="clean"
MAVEN_IMAGE_BUILD_GOAL="fabric8:build"
RF=${RESUME_FROM:-"plugins"}

#
# Apply options
if [ -n "$SKIP_TESTS" ]; then
  echo "Skipping tests ..."
  MAVEN_OPTS="$MAVEN_OPTS -DskipTests"
fi

if [ -n "$SKIP_IMAGE_BUILDS" ]; then
  echo "Skipping image builds ..."
  MAVEN_IMAGE_BUILD_GOAL=""
fi

if [ -n "$NAMESPACE" ]; then
  echo "Namespace: $NAMESPACE"
  MAVEN_OPTS="$MAVEN_OPTS -Dfabric8.namespace=$NAMESPACE"
  OC_OPTS=" -n $NAMESPACE"
fi


if [ -z "$CLEAN" ];then
  MAVEN_CLEAN_GOAL=""
fi

if [ -n "$WITH_IMAGE_STREAMS" ]; then
  echo "With image streams ..."
  MAVEN_OPTS="$MAVEN_OPTS -Dfabric8.mode=openshift"
else
  MAVEN_OPTS="$MAVEN_OPTS -Dfabric8.mode=kubernetes"
fi

git submodule init
git submodule update

for module in $(modules_to_build)
do
  echo "=========================================================="
  echo "Building ${module} ...."
  echo "=========================================================="
  eval "${module}"
done
