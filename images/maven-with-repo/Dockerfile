FROM maven:3.5.0

ENV MAVEN_OPTS=-Dmaven.repo.local=/usr/local/share/maven/repository

RUN mkdir -p /usr/local/share/maven/repository

RUN mkdir -p /usr/local/src && \
    cd /usr/local/src && \
    git clone https://github.com/syndesisio/syndesis.git && \
    cd syndesis && \
    git submodule init && git submodule update

RUN cd /usr/local/src/syndesis/rest && mvn clean install -DskipTests

RUN rm -rf /usr/loca/src/syndesis
