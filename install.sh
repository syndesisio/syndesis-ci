#!/bin/sh

#
# To avoid storing sensitive information publicly the script is using: https://www.passwordstore.org
#

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

#Install Nexus
oc create -f nexus-persistent.yml
oc process nexus \
ROUTE_HOSTNAME=nexus-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -

#Install Maven settings
oc create secret generic m2-settings --from-file=settings.xml
