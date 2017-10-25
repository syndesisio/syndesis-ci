#!/bin/bash

# Exit if any error occurs
set -e

#
# Display a help message.
function displayHelp() {
  echo "This script helps you build the syndesis monorepo."
  echo "The available options are:"
  echo " --with-artifact-prefix  Specifies an prefix for artifacts"
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

#
# Returns the first argument if not empty, the second otherwise
function or() {
  if [ -n "$1" ]; then
    echo $1
  else
    echo $2
  fi
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

function dockerbuild() {
  DOCKERFILE=$1
  IMAGESTREAM=$2
  NAME="$ARTIFACT_PREFIX$IMAGESTREAM"
  BUILD_CONFIG=`oc get bc $OC_OPTS | grep $NAME || echo ""`
  if [ -z "$BUILD_CONFIG" ]; then
    echo "Creating Build Conifg: $NAME"
    cat $DOCKERFILE | oc new-build --name=$NAME --dockerfile=- --to=syndesis/$NAME:$VERSION --strategy=docker $OC_OPTS || true

    # Verify that the build config has been created.
    BUILD_CONFIG=`oc get bc $OC_OPTS | grep $NAME || echo ""`
    if [ -z "$BUILD_CONFIG" ]; then
      echo "Failed to create Build Config: $NAME"
      exit 1
    fi
  fi

  tar -cvf archive.tar .
  oc start-build $NAME $OC_OPTS --from-archive=archive.tar --follow
}

function istag2docker() {
  ISTAG=$1
  oc get istag $OC_OPTS | grep $ISTAG | awk -F " " '{print $2}'
}

function images() {
 pushd images

  # Openshift Jenkins
  pushd openshift-jenkins/2
  dockerbuild Dockerfile openshift-jenkins
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
  oc new-build --binary=true --docker-image=$OPENSHIFT_JENKINS_DOCKER_IMAGE --to=syndesis/syndesis-jenkins:latest --strategy=source $OC_OPTS || true
  tar -cvf archive.tar bin configuration plugins plugins.txt
  oc start-build syndesis-jenkins $OC_OPTS --from-archive=archive.tar --follow
  popd

  popd
}

function agentimages() {
 pushd images/openshift-jenkins

  #
  # Jenkins Agents
  pushd slave-base
  dockerbuild Dockerfile jenkins-slave-base-centos7
  popd

  pushd slave-nodejs
  dockerbuild Dockerfile jenkins-slave-nodejs-centos7
  popd

  pushd slave-maven
  dockerbuild Dockerfile jenkins-slave-maven-centos7
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
CLEAN=$(hasflag --clean "$@" 2> /dev/null)
ARTIFACT_PREFIX=$(readopt --artifact-prefix "$@" 2> /dev/null)
NAMESPACE=$(readopt --namespace "$@" 2> /dev/null)
VERSION=$(or $(readopt --version "$@" 2> /dev/null) "latest")
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
