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



CI_HOME=$PWD
if [ -d $CI_HOME/templates ] && [ -d $CI_HOME/bin ]; then
  echo "Using CI project from: $CI_HOME"
elif [ -d $CI_HOME/../templates ] && [ -d $CI_HOME/../templates ]; then
  CI_HOME=$CI_HOME/../
  echo "Using CI project from: $CI_HOME"
else
  echo "Can't determine which is the CI_HOME. Run the script from the root of the project or from the bin directory."
  exit 1
fi

TMP_KEY_DIR=`mktemp -d`

GPG_ID=`gpg --list-public-keys | grep "rhipaasuser@gmail.com" -B 1 | head -n 1 | tr -d ' '`

#Install maven settings
pushd $CI_HOME/config
mkdir -p $TMP_KEY_DIR/m2

export GPG_NAME=${GPG_ID:(-16)}
export SONATYPE_USERNAME=$(pass show sonatype/syndesisci/username)
export SONATYPE_PASSWORD=$(pass show sonatype/syndesisci/password)

envsubst < settings.xml > $TMP_KEY_DIR/m2/settings.xml

oc create secret generic m2-settings --from-file=$TMP_KEY_DIR/m2/settings.xml

#Install Nexus config file
oc create configmap nexus-config-map --from-file=nexus.xml.file=nexus.xml
popd

#cleanup
unset GPG_NAME
unset SONATYPE_USERNAME
unset SONATYPE_PASSWORD

rm -rf $TMP_KEY_DIR
