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

#
# Maven build
function mvnbuild() {
  echo "Getting project version from: $(pwd)"
  version=$(pomversion)
  echo "Current project version: $version"
  newversion=${version/SNAPSHOT/"syndesis-$VERSION"}
  echo "Changing project version: $newversion"
  mvn versions:set -DnewVersion=$newversion
  echo "Performing maven build: mvn clean install $MAVEN_OPTS"
  mvn clean install $MAVEN_OPTS
  echo "Changing project version: $version"
  mvn versions:set -DnewVersion=$version
}

fromimagename() {
  cat $1 | grep FROM | awk -F "[: ]" '{print $2}'
}

#
# Perform a dockerbuild via build config.
function dockerbuild() {
  DOCKERFILE=$1
  IMAGESTREAM=$2
  BUILDER_IMAGESTREAM=$3
  BUILDER_TAG=${4:-"latest"}
  BC_OPTS=""
  if [ -n "$BUILDER_IMAGESTREAM" ];then
    echo "Using image stream: $BUILDER_IMAGESTREAM"
    BC_OPTS=" --image-stream=$BUILDER_IMAGESTREAM:${BUILDER_TAG}"
  fi

  if [ -n "$BUILDER_TAG" ]; then
    echo "Using image stream tag: $BUILDER_TAG"
    cp $DOCKERFILE  ${DOCKERFILE}.original
    from=$(fromimagename $DOCKERFILE)
    echo "Replace image FROM: $from with $from:$BUILDER_TAG"
    sed -E "s|FROM ([a-zA-Z0-9\.\/\:]+)|FROM ${from}:${BUILDER_TAG}|g" $DOCKERFILE > ${DOCKERFILE}.${BUILDER_TAG}
    cp ${DOCKERFILE}.${BUILDER_TAG} $DOCKERFILE
  fi

  NAME="$ARTIFACT_PREFIX$IMAGESTREAM"
  BUILD_CONFIG=`oc get bc $OC_OPTS | grep $NAME || echo ""`
  if [ -n "$BUILD_CONFIG" ]; then
    # Build config contains a copy of the dockerfile, so we need to always recreate it.
    echo "Removing Build Conifg: $NAME"
    oc delete bc $NAME $OC_OPTS
  fi
  echo "Creating Build Conifg: $NAME"
  cat $DOCKERFILE | oc new-build --name=$NAME --dockerfile=- --to=syndesis/$NAME:$VERSION --strategy=docker $BC_OPTS $OC_OPTS || true

  # Verify that the build config has been created.
  BUILD_CONFIG=`oc get bc $OC_OPTS | grep $NAME || echo ""`
  if [ -z "$BUILD_CONFIG" ]; then
    echo "Failed to create Build Config: $NAME"
    exit 1
  fi

  if [ -f /tmp/archive.tar.gz ]; then
    rm /tmp/archive.tar.gz
  fi

  tar -czvf /tmp/archive.tar.gz . --exclude='.git'
  oc start-build $NAME --from-archive=/tmp/archive.tar.gz $OC_OPTS --follow
  rm /tmp/archive.tar.gz
}

#
# Finds the docker image reference of an image stream tag
function istag2docker() {
  ISTAG=$1
  oc get istag $OC_OPTS | grep $ISTAG | awk -F " " '{print $2}'
}

#
# Prints the version of the pom
function pomversion() {
  # The version is 8 lines from the end.
  # We ditch the rest, cause we can't filter them out (don't have a common pattern).
  # The last 7 lines all start with '['.
  mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -v "\[" | tail -n 1
}

function modules_to_build() {
  modules="plugins agentimages images tools"
  if [ "x${RF}" != x ]; then
    modules=$(echo $modules | sed -e "s/^.*$RF/$RF/")
  fi
  echo $modules
}

#
# Build Modules / Components
#

function plugins() {
  pushd plugins
  #Kubernetes Plugin
  pushd kubernetes-plugin
  git pull --rebase origin master || true
  mvnbuild
  popd

  #Kubernetes Pipeline Plugin
  pushd kubernetes-pipeline-plugin
  git pull --rebase origin master || true
  mvnbuild
  popd

  #Durable Task Pluginresource(s) were provided, but no name, label selector, or --all flag specified
  pushd durable-task-plugin
  git pull --rebase origin master || true
  mvnbuild
  popd

  #Groovy Pipeline Libraries
  pushd workflow-cps-global-lib-plugin
  git pull --rebase origin master || true
  mvnbuild
  popd

  popd
}

function images() {
  pushd images

  # Openshift Jenkins
  pushd openshift-jenkins/2
  git pull --rebase origin master || true

  # Import requirements
  oc import-image origin:v3.6.0 --from=docker.io/openshift/origin:v3.6.0 --confirm || true
  dockerbuild Dockerfile openshift-jenkins origin v3.6.0
  popd

  # Syndesis Jenkins
  pushd syndesis-jenkins
  git pull --rebase origin master || true
  # Let's copy the plugins
  copyplugin kubernetes
  copyplugin durable-task-plugin
  copyplugin workflow-cps-global-lib
  # This is a multimodule project so it does get a little bit more complicated
  copyplugin kubernetes-pipeline-arquillian-steps ../../plugins/kubernetes-pipeline-plugin/arquillian-steps/target/

  # We could possibly remove this?
  #OPENSHIFT_JENKINS_DOCKER_IMAGE=$(istag2docker "${ARTIFACT_PREFIX}openshift-jenkins")
  oc new-build --name ${ARTIFACT_PREFIX}syndesis-jenkins --binary=true --image-stream=${ARTIFACT_PREFIX}openshift-jenkins:$VERSION --to=syndesis/${ARTIFACT_PREFIX}syndesis-jenkins:${VERSION} --strategy=source $OC_OPTS || true
  tar -czvf /tmp/archive.tar.gz bin configuration plugins plugins.txt
  oc start-build ${ARTIFACT_PREFIX}syndesis-jenkins $OC_OPTS --from-archive=/tmp/archive.tar.gz --follow
  rm /tmp/archive.tar.gz
  popd

  popd
}

function agentimages() {
  pushd images/openshift-jenkins

  #
  # Jenkins Agents
  pushd slave-base
  oc import-image origin:v3.6.0 --from=docker.io/openshift/origin:v3.6.0 --confirm || true
  dockerbuild Dockerfile jenkins-slave-base-centos7 origin v3.6.0
  popd

  pushd slave-nodejs
  dockerbuild Dockerfile jenkins-slave-nodejs-centos7 ${ARTIFACT_PREFIX}jenkins-slave-base-centos7 $VERSION
  popd

  pushd slave-maven
  dockerbuild Dockerfile jenkins-slave-maven-centos7 ${ARTIFACT_PREFIX}jenkins-slave-base-centos7 $VERSION
  popd

  popd

  pushd images/jenkins-slave-full-centos7
  dockerbuild Dockerfile jenkins-slave-full-centos7 ${ARTIFACT_PREFIX}jenkins-slave-maven-centos7 $VERSION
  popd
}


function tools() {
  pushd images/nsswrapper-glibc
  oc import-image centos:centos7 --from=docker.io/library/centos:centos7 --confirm || true
  dockerbuild Dockerfile nsswrapper-glibc centos centos7
  popd

  pushd images/maven-with-repo
  oc import-image maven:3.5.0 --from=docker.io/library/maven:3.5.0 --confirm || true
  dockerbuild Dockerfile maven-with-repo maven 3.5.0
  popd
}


#
# Options and flags
SKIP_TESTS=$(hasflag --skip-tests "$@" 2> /dev/null)
CLEAN=$(hasflag --clean "$@" 2> /dev/null)
ARTIFACT_PREFIX=$(readopt --artifact-prefix "$@" 2> /dev/null)
NAMESPACE=$(or $(readopt --namespace "$@" 2> /dev/null) $(oc project -q))
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
