#!/usr/bin/groovy

/**
 * Wraps the code in a podTemplate with the uberPod.
 * A fat agent contains jnlp, maven nodejs and yarn and is meant to be used
 * a one stop build container for syndesis.
 *
 * The idea is to keep avoid using multi container pods for the following reasons:
 * i)  keep things simple (we sacrifice a bit of flexibility).
 * ii) to be able to delegate ALL build logic to shell scripts (easier to test in multiple envs) and keep pipelines to describe the environment.
 *
 * @param parameters Parameters to customize the uberPod.
 * @param body The code to wrap.
 * @return
 */
def call(Map parameters = [:], body) {

    def defaultLabel = buildId('uberpod')
    def label = parameters.get('label', defaultLabel)
    def name = parameters.get('name', 'jnlp') //The container needs to be called jnlp (kubernetes-plugin requirement).

    def cloud = parameters.get('cloud', 'openshift')

    def envVars = parameters.get('envVars', [])
    def inheritFrom = parameters.get('inheritFrom', 'base')
    def namespace = parameters.get('namespace', 'syndesis-ci')
    def serviceAccount = parameters.get('serviceAccount', '')
    def workingDir = parameters.get('workingDir', '/home/jenkins')

    //Maven Parameters
    def mavenRepositoryClaim = parameters.get('mavenRepositoryClaim', '')
    def mavenSettingsXmlSecret = parameters.get('mavenSettingsXmlSecret', '')
    def mavenLocalRepositoryPath = parameters.get('mavenLocalRepositoryPath', "${workingDir}/.m2/repository/")
    def mavenSettingsXmlMountPath = parameters.get('mavenSettingsXmlMountPath', "${workingDir}/.m2")
    def idleMinutes = parameters.get('idle', 10)

    def isPersistent = !mavenRepositoryClaim.isEmpty()
    def hasSettingsXml = !mavenSettingsXmlSecret.isEmpty()

    def internalRegistry = parameters.get('internalRegistry', findInternalRegistry(namespace: "$namespace", imagestream: "jenkins-slave-full-centos7"))
    def image = !internalRegistry.isEmpty() ? parameters.get('image', "${internalRegistry}/${namespace}/jenkins-slave-full-centos7:1.0.8") : parameters.get('image', 'syndesis/jenkins-slave-full-centos7:1.0.8')

    def volumes = []
    envVars.add(containerEnvVar(key: 'MAVEN_OPTS', value: "-Duser.home=${workingDir} -Dmaven.repo.local=${mavenLocalRepositoryPath}"))

    if (isPersistent) {
        volumes.add(persistentVolumeClaim(claimName: "${mavenRepositoryClaim}", mountPath: "${mavenLocalRepositoryPath}"))
    } else {
        volumes.add(emptyDirVolume(mountPath: "${mavenLocalRepositoryPath}"))
    }

    if (hasSettingsXml) {
        volumes.add(secretVolume(secretName: "${mavenSettingsXmlSecret}", mountPath: "${mavenSettingsXmlMountPath}"))
    }

    podTemplate(cloud: "${cloud}", name: "${name}", namespace: "${namespace}", label: label, inheritFrom: "${inheritFrom}", serviceAccount: "${serviceAccount}",
            idleMinutesStr: "${idleMinutes}",
            containers: [containerTemplate(name: "${name}", image: "${image}", command: '/bin/sh -c', args: 'cat', ttyEnabled: true, envVars: envVars)],
            volumes: volumes) {
        body()
    }
}

