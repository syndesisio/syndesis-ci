FROM openshift/jenkins-slave-maven-centos7:latest-slave-maven-centos7:latest

ENV NODEJS_VERSION=4.4 \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH \
    BASH_ENV=/usr/local/bin/scl_enable \
    ENV=/usr/local/bin/scl_enable \
    PROMPT_COMMAND=". /usr/local/bin/scl_enable"

USER root

COPY contrib/bin/scl_enable /usr/local/bin/scl_enable


# Install NodeJS
RUN yum install -y centos-release-scl-rh && \
    INSTALL_PKGS="rh-nodejs4 rh-nodejs4-npm rh-nodejs4-nodejs-nodemon" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

COPY contrib/google-chrome.repo /etc/yum.repos.d/google-chrome.repo

# Install Yarn and Xvfb
RUN curl https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo && \
    yum install -y google-chrome-stable xorg-x11-server-Xvfb liberation-mono-fonts liberation-narrow-fonts liberation-sans-fonts liberation-serif-fonts yarn gcc-c++ make && \
    mkdir /.cache /.config && chmod 777 /.cache /.config && \
    dbus-uuidgen > /etc/machine-id

RUN mkdir -p /usr/local/share/maven/repository

RUN mkdir -p /usr/local/src && \
    cd /usr/local/src && \
    git clone https://github.com/syndesisio/syndesis.git && \
    cd syndesis && \
    git submodule init && git submodule update

RUN cd /usr/local/src/syndesis/rest && /opt/rh/rh-maven33/root/usr/bin/mvn clean install -DskipTests -Dmaven.repo.local=/usr/local/share/maven/repository/

RUN rm -rf /usr/local/src/syndesis

RUN chown -R 1001:0 $HOME && \
    chmod -R g+rw $HOME

RUN chown -R 1001:0 /usr/local/share/maven/repository && \
    chmod -R g+rw /usr/local/share/maven/repository

USER 1001
