# Syndesis CI

Provides a monorepo for the Syndesis CI.

## Building

In order to build everything from source:

    ./bin/build.sh
    
This command will build the following modules:

- plugins
- agentimages
- images 

To resume the build from a particular module, without rebuilding the previous ones:

    ./bin/build.sh --resume-from agentimages

## Installation

Currently there are two flavors provided:

- Ephemeral
- Persistent

### Ephemeral installation

Using the install script:

    ./bin/install.sh --flavor ephemeral 
    
Other options you can pass to the command:

- --clean: Cleans up before installing.
- --domain: The domain to use for routes.
- --host-suffix: The host suffix to use for routes.
- --version: The ci version to use.
    
Note: The installer script assumes the use following:
- [pass](https://pasword-store.org) is used for password management.    
- ssh keys for syndesis exist under ~/.ssh/syndesisci_id_rsa and ~/.ssh/syndesisci_id_rsa.pub.
- gpg keys for rhipaasuser@gmail.com are locally installed.

#### Manually

##### Jenkins

     oc create -f jenkins-ephemeral.yml
     oc process jenkins \
     GITHUB_USERNAME=<github username> \
     GITHUB_PASSWORD=<github password> \
     GITHUB_ACCESS_TOKEN=<github access token password> \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
     KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -
     
and to allow the jenkins service account to provision new projects:

    oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:$(oc project -q):jenkins


##### Nexus

     oc create -f nexus-ephemeral.yml
     oc process nexus \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -

    oc create secret generic m2-settings --from-file settings.xml

### Persistent installation

#### Using the install script

    ./bin/install.sh      

#### Manually

##### Jenkins

     oc create -f jenkins-pvc.yml
     oc create -f jenkins-persistent.yml
     oc process jenkins \
     GITHUB_USERNAME=<github username> \
     GITHUB_PASSWORD=<github password> \
     GITHUB_ACCESS_TOKEN=<github access token password> \
     GITHUB_OAUTH_CLIENT_ID=<github oauth client id> \
     GITHUB_OAUTH_CLIENT_SECRET=<github oauth client secret> \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
     KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -

and to allow the jenkins service account to provision new projects:

    oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:$(oc project -q):jenkins

##### Nexus

     oc create -f nexus-pvc.yml
     oc create -f nexus-persistent.yml
     oc process nexus \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -
     
    oc create secret generic m2-settings --from-file settings.xml
