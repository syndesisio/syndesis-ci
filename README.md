# IPaaS CI

Provides an Openshift Template for Jenkins.

## Installation

Currently there are two flavors provided:

- Ephemeral
- Persistent

### Ephemeral installation

     oc create -f jenkins-ephemeral.yml
     oc process redhat-ipaas-ci \
     GITHUB_USERNAME=<github username> \
     GITHUB_PASSWORD=<github password> \
     GITHUB_ACCESS_TOKEN=<github access token password> \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
     KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -


### Persistent installation

     oc create -f jenkins-pvc.yml
     oc create -f jenkins-persistent.yml
     oc process redhat-ipaas-ci \
     GITHUB_USERNAME=<github username> \
     GITHUB_PASSWORD=<github password> \
     GITHUB_ACCESS_TOKEN=<github access token password> \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
     KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -
