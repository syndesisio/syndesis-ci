#!/bin/sh

#
# To avoid storing sensitive information publicly the script is using: https://www.passwordstore.org
#
# The keys used are the following:

# - dockerhub /syndesisci/email
# - dockerhub/syndesisci/username
# - dockerhub /syndesisci/password
# - github/syndesisci/access_token
# - github/syndesisci/client_id
# - github/syndesisci/password
# - github/syndesisci/secret
# - sonatype/syndesisci/username
# - sonatype/syndesisci/password

# Save global script args
ARGS="$@"
GITHUB_USERNAME=$(or $(readopt --github-username $ARGS 2> /dev/null) "syndesisci")
GITHUB_PASSWORD=$(or $(readopt --github-password $ARGS 2> /dev/null) $(pass show github/syndesisci/password))
GITHUB_ACCESS_TOKEN=$(or $(readopt --github-access-token $ARGS 2> /dev/null) $(pass show github/syndesisci/access_token))
GITHUB_CLIENT_ID=$(or $(readopt --github-client-id $ARGS 2> /dev/null) $(pass show github/syndesisci/client_id))
GITHUB_CLIENT_SECRET=$(or $(readopt --github-client-secret $ARGS 2> /dev/null) $(pass show github/syndesisci/secret))

SONATYPE_USERNAME=$(or $(readopt --sonatype-username $ARGS 2> /dev/null) $(pass show sonatype/syndesisci/username))
SONATYPE_PASSWORD=$(or $(readopt --sonatype-password $ARGS 2> /dev/null) $(pass show sonatype/syndesisci/password))


# Display a help message.
function displayHelp() {
    echo "This script helps you build the syndesis monorepo."
    echo "The available options are:"
    echo ""
    echo " --github-username       The github username to use."
    echo " --github-password       The github password to use."
    echo " --github-access-toke    The github access token to use."
    echo " --github-client-id      The github oauth client id to use."
    echo " --github-client-secret  The github oauth client secret to use."
    echo ""
    echo " --dockerhub-username    The dockerhub username to use for image releases."
    echo " --dockerhub-email       The dockerhub email to use for image releases."
    echo " --dockerhub-passowrd    The dockerhub password to use for image releases."
    echo ""
    echo " --sonatype-username     The sonatype username to use for maven releases."
    echo " --sonatype-passowrd     The sonatype password to use for maven releases."
    echo ""
    echo " --skip-maven-settings    Skips maven settings."
    echo " --skip-release-settings  Skips release settings (gpg & ssh)."
    echo " --domain D               Specifies the domain to use for setting up routes."
    echo " --host-suffix            Specifies the host suffix for setting up routes."
    echo " --namespace N            Specifies the namespace to use."
    echo " --version V              Specifies the version of the templates."
    echo " --help                   Displays this help message."
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

function process_jenkins() {
  oc process jenkins \
     GITHUB_USERNAME=syndesisci \
     GITHUB_PASSWORD=$GITHUB_PASSWORD \
     GITHUB_ACCESS_TOKEN=$GITHUB_ACCESS_TOKEN \
     GITHUB_OAUTH_CLIENT_ID=$GITHUB_CLIENT_ID \
     GITHUB_OAUTH_CLIENT_SECRET=$GITHUB_CLIENT_SECRET \
     ROUTE_HOSTNAME=jenkins$HOSTNAME_SUFFIX.$DOMAIN \
     KUBERNETES_NAMESPACE=$NAMESPACE \
     SYNDESIS_CI_VERSION=${VERSION}
}
#
# Installs Jenkins
function install_jenkins() {
  pushd templates

  if [ -n "$CLEAN" ]; then
    process_jenkins | oc delete -f -
    oc delete template jenkins 2> /dev/null || true
    oc delete pvc jenkins-data 2> /dev/null || true
  fi

  echo "Installing Jenkins at $JENKINS_HOSTNAME using $FLAVOR templates."
  if [ "$FLAVOR" == "persistent" ];then
    oc create -f jenkins-pvc.yml
  fi

  oc create -f jenkins-${FLAVOR}.yml
  process_jenkins | oc create -f -


  oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:syndesis-ci:jenkins
  popd
}
function process_nexus() {
  oc process nexus \
     ROUTE_HOSTNAME=$NEXUS_HOSTNAME
}

#
# Installs nexus
function install_nexus() {
  pushd templates

  if [ -n "$CLEAN" ]; then
    process_nexus | oc delete -f -
    oc delete template nexus 2> /dev/null || true
    oc delete pvc nexus-data 2> /dev/null || true
    oc delete configmap nexus-config-map
  fi


  echo "Installing Nexus at $NEXUS_HOSTNAME using $FLAVOR templates."
  if [ "$FLAVOR" == "persistent" ];then
    oc create -f nexus-pvc.yml
  fi
  oc create -f nexus-${FLAVOR}.yml
  process_nexus | oc create -f -

  popd
  #Install Nexus config file
  pushd $CI_HOME/config
  oc create configmap nexus-config-map --from-file=nexus.xml.file=nexus.xml
  popd
}

function install_ssh_keys() {
  if [ -n "$CLEAN" ]; then
    oc delete secret ssh-keys
  fi

  TMP_KEY_DIR=`mktemp -d`
  #Install ssh keys
  mkdir -p $TMP_KEY_DIR/ssh-keys
  chmod +x $TMP_KEY_DIR/ssh-keys
  cp ~/.ssh/syndesisci_id_rsa $TMP_KEY_DIR/ssh-keys/id_rsa
  cp ~/.ssh/syndesisci_id_rsa.pub $TMP_KEY_DIR/ssh-keys/id_rsa.pub
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ${TMP_KEY_DIR}/ssh-keys/config
  oc create secret generic ssh-keys --from-file=$TMP_KEY_DIR/ssh-keys/id_rsa --from-file=$TMP_KEY_DIR/ssh-keys/id_rsa.pub --from-file=$TMP_KEY_DIR/ssh-keys/config

  rm -rf $TMP_KEY_DIR
}

function install_gpg_keys() {
  if [ -n "$CLEAN" ]; then
    oc delete secret gpg-keys
  fi

  TMP_KEY_DIR=`mktemp -d`

  #Install gpg keys (This requires that a key with email rhipaasuser@gmail.com exists).
  mkdir -p $TMP_KEY_DIR/gpg-keys
  chmod +x $TMP_KEY_DIR/gpg-keys
  GPG_ID=`gpg --list-public-keys | grep "rhipaasuser@gmail.com" -B 1 | head -n 1 | tr -d ' '`
  gpg --export ${GPG_ID} > $TMP_KEY_DIR/gpg-keys/public.key
  gpg --export-secret-key ${GPG_ID} > $TMP_KEY_DIR/gpg-keys/private.key
  oc create secret generic gpg-keys --from-file=$TMP_KEY_DIR/gpg-keys/public.key --from-file=$TMP_KEY_DIR/gpg-keys/private.key
  rm -rf $TMP_KEY_DIR
}

function install_maven_settings() {
  TMP_KEY_DIR=`mktemp -d`
  pushd templates

  if [ -n "$CLEAN" ]; then
    oc delete secret m2-settings
    oc delete -f m2-bc.yml
  fi

  if [ -z "$SONATYPE_USERNAME" ]; then
    echo "Sonatype username not found. Please specify using --sonatype-username, or setup sonatpye/syndesisci/username on password store."
  fi

  if [ -z "$SONATYPE_PASSWORD" ]; then
    echo "Sonatype password not found. Please specify using --sonatype-password, or setup sonatype/syndesisci/password on password store.."
  fi

  #Install maven build config
  oc create -f m2-bc.yml
  #Install maven settings
  pushd $CI_HOME/config
  mkdir -p $TMP_KEY_DIR/m2

  GPG_ID=`gpg --list-public-keys | grep "rhipaasuser@gmail.com" -B 1 | head -n 1 | tr -d ' '`
  export GPG_NAME=${GPG_ID:(-16)}
  export SONATYPE_USERNAME
  export SONATYPE_PASSWORD

  envsubst < settings.xml > $TMP_KEY_DIR/m2/settings.xml

  oc create secret generic m2-settings --from-file=$TMP_KEY_DIR/m2/settings.xml
  popd
  rm -rf $TMP_KEY_DIR

  #cleanup
  unset GPG_NAME
  unset SONATYPE_USERNAME
  unset SONATYPE_PASSWORD
}

function install_dockerhub_secret() {
  if [ -n "$CLEAN" ]; then
    oc delete secret dockerhub
  fi
  #Install dockerhub secret
  if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo "Dockerhub username not found. Please specify using --dockerhub-username, or setup dockerhub/syndesisci/username on password store."
  fi

  if [ -z "$DOCKERHUB_EMAIL" ]; then
    echo "Dockerhub email not found. Please specify using --dockerhub-email, or setup dockerhub/syndesisci/email on password store.."
  fi

  if [ -z "$DOCKERHUB_PASSWORD" ]; then
    echo "Dockerhub password not found. Please specify using --dockerhub-password, or setup dockerhub/syndesisci/password on password store.."
  fi
  oc secrets new-dockercfg dockerhub --docker-server=https://index.docker.io/v1/ --docker-username=$DOCKERHUB_USERNAME --docker-password=$DOCKERHUB_PASSWORD --docker-email=$DOCKERHUB_EMAIL
}

function init() {
  if [ -d $CI_HOME/templates ] && [ -d $CI_HOME/bin ]; then
    echo "Using CI project from: $CI_HOME"
  elif [ -d $CI_HOME/../templates ] && [ -d $CI_HOME/../templates ]; then
    CI_HOME=$CI_HOME/../
    echo "Using CI project from: $CI_HOME"
  else
    echo "Can't determine which is the CI_HOME. Run the script from the root of the project or from the bin directory."
    exit 1
  fi

}

HELP=$(hasflag --help "$@" 2> /dev/null)
CLEAN=$(hasflag --clean $ARGS 2> /dev/null)
NAMESPACE=$(or $(readopt --namespace $ARGS 2> /dev/null) $(oc project -q))
FLAVOR=$(or $(readopt --flavor $ARGS 2> /dev/null) "persistent")
VERSION=$(or $(readopt --version $ARGS 2> /dev/null) "latest")
HOSTNAME_SUFFIX=$(or $(readopt --hostname-suffix $ARGS 2> /dev/null) "-$NAMESPACE")
DOMAIN=$(or $(readopt --domain $ARGS 2> /dev/null) "b6ff.rh-idev.openshiftapps.com")

SKIP_MAVEN_SETTINGS=$(hasflag --skip-maven-settings $ARGS 2> /dev/null)
SKIP_RELEASE_SETTINGS=$(hasflag --skip-release-settings $ARGS 2> /dev/null)

GITHUB_USERNAME=$(or $(readopt --github-username $ARGS 2> /dev/null) "syndesisci")
GITHUB_PASSWORD=$(or $(readopt --github-password $ARGS 2> /dev/null) $(pass show github/syndesisci/password))
GITHUB_ACCESS_TOKEN=$(or $(readopt --github-access-token $ARGS 2> /dev/null) $(pass show github/syndesisci/access_token))
GITHUB_CLIENT_ID=$(or $(readopt --github-client-id $ARGS 2> /dev/null) $(pass show github/syndesisci/client_id))
GITHUB_CLIENT_SECRET=$(or $(readopt --github-client-secret $ARGS 2> /dev/null) $(pass show github/syndesisci/secret))

SONATYPE_USERNAME=$(or $(readopt --sonatype-username $ARGS 2> /dev/null) $(pass show sonatype/syndesisci/username))
SONATYPE_PASSWORD=$(or $(readopt --sonatype-password $ARGS 2> /dev/null) $(pass show sonatype/syndesisci/password))

DOCKERHUB_USERNAME=$(or $(readopt --dockerhub-username $ARGS 2> /dev/null) $(pass show dockerhub/syndesisci/username))
DOCKERHUB_EMAIL=$(or $(readopt --dockerhub-email $ARGS 2> /dev/null) $(pass show dockerhub/syndesisci/email))
DOCKERHUB_PASSWORD=$(or $(readopt --dockerhub-password $ARGS 2> /dev/null) $(pass show dockerhub/syndesisci/password))

if [ -n "$HELP" ]; then
   displayHelp
   exit 0
fi

JENKINS_HOSTNAME="jenkins$HOSTNAME_SUFFIX.$DOMAIN"
NEXUS_HOSTNAME="nexus$HOSTNAME_SUFFIX.$DOMAIN"

CI_HOME=$PWD
init
install_jenkins
install_nexus

install_ssh_keys
install_gpg_keys
install_maven_settings
install_dockerhub_secret
