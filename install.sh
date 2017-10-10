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


oc create -f jenkins-pvc.yml
oc create -f nexus-pvc.yml
oc create -f jenkins-persistent.yml

#Install Jenkins
oc process jenkins \
GITHUB_USERNAME=syndesisci \
GITHUB_PASSWORD=$(pass show github/syndesisci/password) \
GITHUB_ACCESS_TOKEN=$(pass show github/syndesisci/access_token) \
GITHUB_OAUTH_CLIENT_ID=$(pass show github/syndesisci/client_id) \
GITHUB_OAUTH_CLIENT_SECRET=$(pass show github/syndesisci/secret) \
ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
KUBERNETES_NAMESPACE=$(oc project -q) \
OPENSHIFT_MASTER=$(oc whoami --show-server) | oc create -f - \

#Install maven build config
oc create -f m2-bc.yml

#Install Nexus
oc create -f nexus-persistent.yml
oc process nexus \
ROUTE_HOSTNAME=nexus-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -


TMP_KEY_DIR=`mktemp -d`

#Install gpg keys (This requires that a key with email rhipaasuser@gmail.com exists).
mkdir -p $TMP_KEY_DIR/gpg-keys
chmod +x $TMP_KEY_DIR/gpg-keys
GPG_ID=`gpg --list-public-keys | grep "rhipaasuser@gmail.com" -B 1 | head -n 1 | tr -d ' '`
gpg --export ${GPG_ID} > $TMP_KEY_DIR/gpg-keys/public.key
gpg --export-secret-key ${GPG_ID} > $TMP_KEY_DIR/gpg-keys/private.key
oc create secret generic gpg-keys --from-file=$TMP_KEY_DIR/gpg-keys/public.key --from-file=$TMP_KEY_DIR/gpg-keys/private.key

#Let's import everything into the tmp .gnupg so that we can make a secret out of it.
#gpg --homedir=$TMP_KEY_DIR --import $TMP_KEY_DIR/.gnupg/public.key 
#gpg --homedir=$TMP_KEY_DIR --import $TMP_KEY_DIR/.gnupg/private.key
#rm -rf  $TMP_KEY_DIR/.gnupg/public.key  $TMP_KEY_DIR/.gnupg/private.key

#Install ssh keys
mkdir -p $TMP_KEY_DIR/ssh-keys
chmod +x $TMP_KEY_DIR/ssh-keys
cp ~/.ssh/syndesisci_id_rsa $TMP_KEY_DIR/ssh-keys/id_rsa
cp ~/.ssh/syndesisci_id_rsa.pub $TMP_KEY_DIR/ssh-keys/id_rsa.pub
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ${TMP_KEY_DIR}/ssh-keys/config
oc create secret generic ssh-keys --from-file=$TMP_KEY_DIR/ssh-keys/id_rsa --from-file=$TMP_KEY_DIR/ssh-keys/id_rsa.pub --from-file=$TMP_KEY_DIR/ssh-keys/config

#Install maven settings
mkdir -p $TMP_KEY_DIR/m2

export GPG_NAME=${GPG_ID:(-16)}
export SONATYPE_USERNAME=$(pass show sonatype/syndesisci/username)
export SONATYPE_PASSWORD=$(pass show sonatype/syndesisci/password)

envsubst < settings.xml > $TMP_KEY_DIR/m2/settings.xml

oc create secret generic m2-settings --from-file=$TMP_KEY_DIR/m2/settings.xml

#Install dockerhub secret
oc secrets new-dockercfg dockerhub --docker-server=https://index.docker.io/v1/ --docker-username=$(pass show dockerhub/syndesisci/username) --docker-password=$(pass show dockerhub/syndesisci/password) --docker-email=$(pass show dockerhub/syndesisci/email)

#Install Nexus config file
oc create configmap nexus-config-map --from-file=nexus.xml.file=nexus.xml

#cleanup
unset GPG_NAME
unset SONATYPE_USERNAME
unset SONATYPE_PASSWORD

rm -rf $TMP_KEY_DIR
