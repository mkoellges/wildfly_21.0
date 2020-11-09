# Use Ubuntu images incl. Java11
#
#    docker build --t mkoellges/wildfly:21.0 .

FROM mkoellges/ubuntu:java11

ARG WILDFLY_VERSION=21.0.0.Final
ARG PROMETHEUS_EXPORTER_VERSION=0.0.5

LABEL MAINTAINER=manfred.koellges@metronom.com

# Set the WILDFLY_VERSION env variable
ENV JBOSS_BASE_DIR=/opt/jboss/standalone
ENV JBOSS_HOME=/opt/jboss
ENV PATH=${JBOSS_HOME}/bin:/u01/bin:$PATH
ENV JBOSS_CONFIG_DIR=${JBOSS_BASE_DIR}/configuration
# ENV JAVA_OPTS="-server -Djava.net.preferIPv4Stack=true -Djboss.modules.system.pkgs=org.jboss.byteman -Djava.awt.headless=true -Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
ENV JAVA_OPTS="-server -Djava.net.preferIPv4Stack=true -Djboss.modules.system.pkgs=org.jboss.byteman -Djava.awt.headless=true  -XX:MaxRAMPercentage=50"
ENV JVM_PARAM=""
ENV JAVA_OPTS_EXT=""
ENV CONFIG_TYPE="standalone-ha"
ENV LAUNCH_JBOSS_IN_BACKGROUND=true
ENV JBOSS_PWD="change_me1"
ENV ETCD_NODES=""
ENV MCASTADDRESS="230.0.0.4"
ENV USE_FILEBEAT=0
ENV USE_EXISTING=0


# Set System Settings
RUN echo "# Allow a 25MB UDP receive buffer for JGroups  " >> /etc/sysctl.conf && \
    echo "net.core.rmem_max = 26214400 " >> /etc/sysctl.conf && \
    echo "# Allow a 1MB UDP send buffer for JGroups  " >> /etc/sysctl.conf && \
    echo "net.core.wmem_max = 1048576 " >> /etc/sysctl.conf 

# USER nobody

# Install the Software
RUN cd /tmp && \
    wget http://download.jboss.org/wildfly/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.zip && \
    cd /opt && \
    unzip /tmp/wildfly-${WILDFLY_VERSION}.zip && \
    rm /tmp/wildfly-${WILDFLY_VERSION}.zip && \
    mv /opt/wildfly-${WILDFLY_VERSION}/ /opt/jboss && \
    mkdir -p /opt/jboss/modules/system/layers/base/com/oracle/main && \
    mkdir -p /opt/jboss/modules/system/layers/base/com/mysql/main && \
    mkdir -p /opt/jboss/modules/system/layers/base/com/postgresql/main && \
    mkdir -p /opt/jboss/batch && \
    mkdir -p /opt/application/java && \
    mkdir -p /opt/application/appconfig

WORKDIR /opt/jboss/standalone

EXPOSE 8080 9990

COPY bin/* /opt/jboss/bin/
COPY cli/* /opt/jboss/batch/
COPY jolokia-war-1.6.2.war /opt/jboss/standalone/deployments/jolokia.war
COPY wmq.jmsra.rar /opt/application/appconfig/wmq.jmsra.rar
COPY confd /u01/bin/
COPY oracle/* /opt/jboss/modules/system/layers/base/com/oracle/main/
COPY mysql/* /opt/jboss/modules/system/layers/base/com/mysql/main/
COPY postgres/* /opt/jboss/modules/system/layers/base/com/postgresql/main/
COPY prometheus/wildfly_exporter_module-$PROMETHEUS_EXPORTER_VERSION.jar /opt/jboss/modules/
COPY prometheus/wildfly_exporter_servlet-$PROMETHEUS_EXPORTER_VERSION.war /opt/jboss/standalone/deployments/

RUN /opt/jboss/bin/config_db_driver.sh  && rm /opt/jboss/bin/config_db_driver.sh
RUN cd /opt/jboss/modules/ && \
    jar -xvf wildfly_exporter_module-$PROMETHEUS_EXPORTER_VERSION.jar && \
    rm -rf META-INF && \
    rm -f wildfly_exporter_module-$PROMETHEUS_EXPORTER_VERSION.jar

ENTRYPOINT ["/opt/jboss/bin/start_jboss.sh"]
