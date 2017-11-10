# Syndesis CI

Provides a monorepo for the Syndesis CI.

## Building
  In order to build everything a build script is provided at: `bin/build.sh`.

  The script will start by building:

  - custom jenkins plugins:
    - kubernetes-plugin
    - kubernetes-pipeline-plugin
    - durable-task-plugin
    - workflow-cps-global-lib-plugin
  - slave images
    - slave-base
    - slave-agent
    - slave-nodejs
  - images
    - openshift jenkins image (customized image for s2i use)
    - syndesis jenkins image

  The script can be used like:

```
./bin/build.sh
```

  The script accepts the following flags:

| Flag     | Description                                          |
|----------|------------------------------------------------------|
| --clean  | Specifies the namespace to use                       |
| --help   | Displays a use message                               |

  It can also be parameterized using the following parameters:

 | Parameter         | Description                                          |
 |-------------------|------------------------------------------------------|
 | --namespace       | The namespace to build images into                   |
 | --resume-from     | Resume build from modules (agentimages, images)      |
 | --version         | The version of the artifacts to build                |
 | --artifact-prefix | The artifact prefix (to prevent clashes)             |
 
## Installing

#### Using a script

  In a similar manner the repo also contains an installation script, that can be used to install:

  - jenkins
  - nexus
  - build tooling configuration
    - maven settings.xml
  - release tooling configuration
    - ssh keys
    - gpg keys

```
./bin/install.sh
```

  The script accepts the following flags:

|----------|------------------------------------------------------|
| Flag     | Description                                          |
|----------|------------------------------------------------------|
| --clean  | Specifies the namespace to use                       |
| --help   | Displays a use message                               |
|----------|------------------------------------------------------|

  It can also be parameterized using the following parameters:

|-------------------------|------------------------------------------------------|
| Parameter               | Description                                          |
|-------------------------|------------------------------------------------------|
| --flavor                | The template type to use (ephemeral, persistent)     |
| --namespace             | The namespace to install CI into                     |
| --version               | The version of the artifacts to build                |
| --domain                | The domain to use for creating routes                |
| --host-suffix           | A suffix to append in the route host name            |
| --skip-maven-settings   | Don't install the maven settings                     |
| --skip-release-settings | Don't install the release settings                   |

  A special category of parameters that is related to passing sensitive information:

| Parameter               | Description                                   |
|-------------------------|-----------------------------------------------|
| --github-username       | The github username                           |
| --github-password       | The github password                           |
| --github-access-token   | The github access token                       |
| --github-client-id      | The github client id                          |
| --github-client-secret  | The github client secret                      |
| --sonatype-username     | The sonatype username                         |
| --sonatype-password     | The sonatype password                         |
| --dockerhub-username    | The dockerhub username                        |
| --dockerhub-email       | The dockerhub email                           |
| --dockerhub-password    | The dockerhub password                        |


Note: Depending on the components you are installing, the installer will require access to sensitive information like keys, passwords etc. Those can be passed with the parameters shown above or using [pass](https://password-store.org).

Other things that are required by the release modules, that need to be setup in your environment (if you need to install the release components) are:

- ssh keys for syndesis exist under ~/.ssh/syndesisci_id_rsa and ~/.ssh/syndesisci_id_rsa.pub.
- gpg keys for rhipaasuser@gmail.com are locally installed.

#### Manually

##### Jenkins

Currently there are two flavors provided:

- Ephemeral
- Persistent

###### Ephemeral installation

     oc create -f jenkins-ephemeral.yml
     oc process jenkins \
     GITHUB_USERNAME=<github username> \
     GITHUB_PASSWORD=<github password> \
     GITHUB_ACCESS_TOKEN=<github access token password> \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com \
     KUBERNETES_NAMESPACE=$(oc project -q) | oc create -f -
     
and to allow the jenkins service account to provision new projects:

    oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:$(oc project -q):jenkins


###### Persistent installation

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

###### Ephemeral installation

     oc create -f nexus-ephemeral.yml
     oc process nexus \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -

    oc create secret generic m2-settings --from-file settings.xml


###### Persistent installation

     oc create -f nexus-pvc.yml
     oc create -f nexus-persistent.yml
     oc process nexus \
     ROUTE_HOSTNAME=jenkins-$(oc project -q).b6ff.rh-idev.openshiftapps.com | oc create -f -
     
    oc create secret generic m2-settings --from-file settings.xml
