
# Table of Contents

1.  [Requirements](#orgb4106b1)
    1.  [Git Workflow](#org81903aa)
        1.  [Pull Request](#org9115c45)
        2.  [Merge](#org99a9718)
        3.  [Release](#orgbf63391)
    2.  [Building](#org358757e)
        1.  [Integrate with hipster build tools](#orge2458f8)
    3.  [Testing](#org1bcb7f7)
        1.  [End to end testing](#orge2d2e6b)
    4.  [Deployment](#org0ba162f)
        1.  [Auto Stage](#org01ed0b0)
2.  [Limitations](#orga361a3f)
    1.  [Circle CI](#org4a08787)
        1.  [1 concurrent build (per project? per organization?).](#org2a70536)
        2.  [1500 minutes testing minutes per month.](#org867b4de)
3.  [Proposals](#org6a2ab4e)
    1.  [Move to CircleCI](#org0a4a029)
        1.  [Pros](#org2bb91b7)
        2.  [Cons](#org3fbb059)
    2.  [Keep Jenkins](#org3733765)
        1.  [Pros](#orgf4135a1)
        2.  [Cons](#org3dd65c5)
    3.  [Simplify Jenkins](#org6658d88)
        1.  [Examples:](#org272a418)



<a id="orgb4106b1"></a>

# Requirements


<a id="org81903aa"></a>

## Git Workflow


<a id="org9115c45"></a>

### Pull Request

-   trigger jobs on pull request
-   re-triggering on update
-   re-triggering using a phrase


<a id="org99a9718"></a>

### Merge

-   support merging a pull request using a comment / label.


<a id="orgbf63391"></a>

### Release

-   release maven artifacts
-   release docker images
-   npm (?)
-   handle git tags
-   promote to production.


<a id="org358757e"></a>

## Building


<a id="orge2458f8"></a>

### Integrate with hipster build tools

-   Basel
-   Buck


<a id="org1bcb7f7"></a>

## Testing


<a id="orge2d2e6b"></a>

### End to end testing

What we actually need is to be able to spin up test environments (preferably ephemeral) and be able to know when they are ready so that we can bootstrap out test suite.

1.  Cube-like features

2.  Polyglot

    Our existing end to end tests are written in somethingscirpt.


<a id="org0ba162f"></a>

## Deployment


<a id="org01ed0b0"></a>

### Auto Stage

-   automatically stage changes upon merge
-   deploy snapshots and latest (?)


<a id="orga361a3f"></a>

# Limitations


<a id="org4a08787"></a>

## Circle CI

We need to check if there are considerations, of setting up access tokens to our environments.


<a id="org2a70536"></a>

### 1 concurrent build (per project? per organization?).


<a id="org867b4de"></a>

### 1500 minutes testing minutes per month.


<a id="org6a2ab4e"></a>

# Proposals


<a id="org0a4a029"></a>

## Move to CircleCI

We ditch all things Jenkins and we keep CircleCI as our only CI environment.
At the moment it does pull request validation and can also publish images and do roll outs (needs some coordination there).
What needs to be done is find a way to orchestrate end to end tests.


<a id="org2bb91b7"></a>

### Pros

1.  Provided as a service (we don't manage it ourselves)

2.  External

    1.  Has access to Docker daemon
    
    2.  Connects to Openshift as cluster admin


<a id="org3fbb059"></a>

### Cons

1.  The free tier is limited

2.  Vendor lock

3.  Sharing sensitive information (keys etc) with an external service.

4.  Orchestrating end to end tests, needs to be implemented from scratch.


<a id="org3733765"></a>

## Keep Jenkins

We keep Jenkins and try to improve on what we already have.


<a id="orgf4135a1"></a>

### Pros

1.  Flexible

2.  Well-known


<a id="org3dd65c5"></a>

### Cons

1.  A lot of moving parts

    1.  Adds to the learning curve
    
    2.  Large surface area, more prone to bugs

2.  Being inside Openshift

    1.  Issues with sharing volumes
    
    2.  Service Accounts are somehow harder to reason that plain users


<a id="org6658d88"></a>

## Simplify Jenkins

We revisit our setup trying to reduce the moving parts. We have the freedom to sacrifice things that are not that important to gain simplicity.


<a id="org272a418"></a>

### Examples:

1.  Move outside of Openshift

    Connect to Openshift externally as a cluster-admin to eliminate security pampering.

2.  Don't provision dynamically agents

    Use a pool of fat containers and form a swarm to reduce our moving parts.

3.  Don't use agents at all.

    That's maybe too much, but if we can live with one concurrent build that CircleCI offers, then why not?

