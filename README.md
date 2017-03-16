# IPaaS CI

Provides an Openshift Template for Jenkins.

## Installation

Currently there are two falvors provided:

- Ephemeral
- Persistent

### Ephemeral installation

     oc create -f jenkins-ephemeral.yml
     oc process redhat-ipaas-ci ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -


### Persistent installation

     oc create -f jenkins-pvc.yml
     oc create -f jenkins-persistent.yml
     oc process redhat-ipaas-ci ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -
