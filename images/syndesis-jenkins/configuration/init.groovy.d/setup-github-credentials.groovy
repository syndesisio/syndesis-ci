import jenkins.model.*

import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

import hudson.util.*;
import hudson.plugins.sshslaves.*;

import org.jenkinsci.plugins.plaincredentials.impl.*;


domain = Domain.global()
store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

def env = System.getenv()

//Add credentials for github account
githubAccount = new UsernamePasswordCredentialsImpl(
        CredentialsScope.GLOBAL,
        "github", "Github Account Credentials",
        env["GITHUB_USERNAME"],
        env["GITHUB_ACCESS_TOKEN"] //this is intentional. We pass the access token as a password.
)

githubAccessToken = new StringCredentialsImpl(
        CredentialsScope.GLOBAL,
        "githubaccesstoken",
        "Github Access Token",
        Secret.fromString(env["GITHUB_ACCESS_TOKEN"]))

store.addCredentials(domain, githubAccount)
store.addCredentials(domain, githubAccessToken)