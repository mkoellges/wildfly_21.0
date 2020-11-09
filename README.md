## Basics
---

This container contains the Wildfly community version of Wildfly. The structure of the Wildfly container is
```sh
/opt/                               # Base directory
     application/                   # All application related files are stored here
          appconfig/                # configuration yml files that define subsystems like datasources, logging adapters etc. 
          java/                     # Application Archives (earfiles, warfiles or jarfiles) that needs to be deployed
     data/                          # static files
     jboss/                         # application server software (Wildfly install directory)
````

In this documentation the following variables are used:

```sh
JBOSS_HOME=/opt/jboss
JBOSS_BASE_DIR=${WILDFLY_HOME}/standalone
JBOSS_CONFIG_DIR=${WILDFLY_BASE_DIR}/configuration

WORKING_DIR=${WILDFLY_BASE_DIR}

APPLICATION_STAGE_DIR=/opt/application/java
YML_STAGE_DIR=/opt/application/appconfig
````

The Wildfly Docker image runs on base on Docker image registry.metroscales.io/asm/ubuntu:java[RELEASE] - means, that the Wildfly is running on top of Ubuntu Linux and a supported OpenJDK release.

In this Wildfly instances, the following Database drivers are already installed:

- Oracle RDBMS
- Postgres
- MySQL

After the wildfly instance is up and running, you can access the admin URL it using http://[HOSTNAME]:9990 .

Username:  admin
Password:  default is "change_me1", but you can use your own by changing the ENV Parameter "JBOSS_PWD"

To store static files  that are referenced in your application use the directory.

```sh
/opt/data
````

This directory can be accessed inside of your application using the Webresource location /mydata - use this location inside your application to consume the static files.

## Run the container
---

This way starts the container in a method, that all JVM parameters can be passed on command line call for the docker run.

```sh
docker run -d \
       --env JVM_PARAM=" -Xms2048m -Xmx2048m" \
       --env CONFIG_TYPE="standalone" \
       --env JBOSS_PWD="change_me1" \
       --name [MY_NAME] \
       -p 9990:9990 \
       -p 8080:8080 \
      registry.metroscales.io/[YOURPROJECTNAME]/[YOURIMAGENAME]:[YOUR_VERSION_TAG]
````

The environment parameter JVM_PARAM can include all JVM parameters and options needed. The environment parameter JVM_PWD defines the password of the Web Admin Console.
The CONFIG_TYPE can be all possible standalone profiles like standalone, standalone-ha, standalone-full and standalone-full-ha

## Check if the container is running from an external loadbalancer (F5)
---

If the container shall be used behind a F5 Loadbalancer (Big-IP), the probing of the connectivity between loadbalancer and Application server can be done using the URI "/check.html". This will return a small html file with the content
"Ich bin die MidTier CONTAINERNAME"
where CONTAINERNAME is the "hostname" of the running, just started container.

## Deployment of an application
---

### 1. Deploy the application archive (war, ear or jar)
To ensure that your container contains your software, copy the application archive (.jar, .war or .ear) to the container directory ${APPLICATION_STAGE_DIR} mentioned above. When it is part in this directory it will be deployed on start of the container. You do not need to do anything - simply copy the file.

If you have more than one application that needs to be deployed - copy all your application archives in this directory. If you have to deploy them in an order, name them with a prefix like '01-application1.ear', '02-application2.ear' etc. Then the order of the numbers will be taken care and the archives will be deployed on container start in this order.

### 2. Create a data-source definition file
Define the values in a yml file on the machine you are working with a name of the file of your choice. Inside of the container, the filename must be data-source.yml and it must be placed in the directoy ${YML_STAGE_DIR} mentioned above. To be able to stage your application, do not copy the data-source.yml file into the container - mount it to this ${YML_STAGE_DIR}/data-source.yml at runtime of your container.

Example of a data-source.yml file:

```yml
DSNAME:
  jndi-name: java:jboss/datasources/DSNAME
  dbtype: DBTYPE
  user-name: USERNAME 
  password: PASSWORD
  connection-url: CONNECTION-URL
```

It is possible to define more than one database using additional yml sections. All parameter of JDBC configuration for Wildfly can be used. Check the original documentation of Wildfly here: https://wildscribe.github.io/WildFly/10.1/subsystem/datasources/data-source/index.html.

The following databases are supported, their drivers are already installed and they use the following urls:

```sh
MySql    :  jdbc:mysql://[IP Address or Nodename]:[Port]/[DBName]
Postgres :  jdbc:postgresql://[IP Address or Nodename]:[Port]/[DBName]
Oracle   :  jdbc:oracle:thin:@[IP Address or Nodename]:[Port]:[SID or ServiceName]
````

The connection configuration parameter are not required. If none of the following parameter is set in the yml file, the default values below are used:

```sh
min-pool-size="10"
max-pool-size="30"
```

Minimalist example:

```yml
AsminvPg:
   jndi-name: "java:/AsminvPg"
   driver-name: postgresql
   connection-url: "jdbc:postgresql://10.96.146.242:5432/mydatabase"
   user-name: "myuser"
   password: "mypassword"
```

### 3. Create a resource adapter

You can define resource adapter by creating a definition of it in a yml file with a name of your choice.  This file must be added to the container in the directory ${YML_STAGE_DIR} and must have the name resourceadapter.yml. To be able to stage your application, do not copy the resourceadapter.yml file into the container - mount it to this ${YML_STAGE_DIR}/resourceadapter.yml at runtime of your container.
For resourceadapter.yml structure, we have the next restrictions:
- the entire structure must be declared (mq_adapter_name, mq_connectionfactory_name)
- mq_adapter_name: - must be on the first line of a group definition
- mq_connectionfactory_name - must be declared before their child properties
We support the external message bus "IBM MQSeries". The drivers needed to communicate with it are already installed.
Here is an example of a resource adapter configuration file:

```yml
mq_adapter_name: MQ.ADAPTER.DEV                                              # required
mq_adapter_archive: wmq.jmsra.rar                                            # required
mq_adapter_transaction_support: LocalTransaction                             # required
mq_connectionfactory_name: WMQConnectionFactoryPool                          # required
mq_connectionfactory_connection_name_list: h251serv.metro-dus.de(14200)      # required
mq_connectionfactory_jndi_name: java:jboss/eis/MQCF                          # required
mq_connectionfactory_transporttype: CLIENT                                   # required
mq_queue_manager: MQSD.H251E02                                               # required
mq_channel_name: SYSTEM.DEF.SVRCONN                                          # required
mq_connectionfactory_pool_max: 10                                            # required
mq_connectionfactory_pool_min: 1                                             # required
```

In this example the 'wmq.jmsra.rar' is an IBM archive file (used for WebSphere MQ resource adapter). For more information related to this archive you can visit: https://www-01.ibm.com/support/docview.wss?uid=swg21668491

### 4. Create a logging profile

You can define logging profiles by creating a definition of it in a yml file with a name of your choice. This file must be added to the container in the directory ${YML_STAGE_DIR} and must have the name loggingprofile.yml. To be able to stage your application, do not copy the loggingprofile.yml file into the container - mount it to this ${YML_STAGE_DIR}/loggingprofile.yml at runtime of your container.

For loggingprofile.yml structure, we have the next restrictions:
the indentation must be made with 2 spaces for each level
the parameter values must not contain the next symbols: §±!
the loggers' definitions must be in sequence (one after one)
the max_backup_index value must be an integer
The rotation can be based on the size of the log file or on time split.

Example of size rotation:

```yml
mccm_be_mcc_v3:
  log_format: "%d|%t|%-7p|%c| %m%n"
  log_ocular: false
  logger:
    net.metrosystems.ai:
      level: ERROR
    org.jboss.modules:
      level: ERROR
    com.arjuna:
      level: ERROR
  rotate_by: size
  rotate_size: 5m
  max_backup_index: 10
```

Notes:
    For 'size' rotation there is a limit of maximum 500MB for all log files.
    If no filesize is specified then 50MB is used as a default value.
    If max_backup_index is missing then 10 is used as a default value.

Other examples for file sizing:

    10 files (max_backup_index) with 10K rotate_size -> then the total amount of log files will be 50KB
    8 files (max_backup_index) with 10M rotate_size -> then the total amount of log files will be 80MB
    5 files (max_backup_index) with 20M rotate_size -> then the total amount of log files will be 100MB
    6 files (max_backup_index) with 30M rotate_size -> then the total amount of log files will be 180MB
    7 files (max_backup_index) with 30M rotate_size -> then the total amount of log files will be 210MB
    12 files (max_backup_index) with 1M rotate_size -> then the total amount of log files will be 12MB
    15 files (max_backup_index) with 8K rotate_size -> then the total amount of log files will be 120KB
    12 files (max_backup_index) with 60M rotate_size -> then the total amount of log files will be 480MB -> 8 files with 60MB each

Example for the same logging with time rotation (with 8 x 50K = 400KB -> the total amount of flog files):

```yml
mccm_be_mcc_v3:
  log_format: "%d|%t|%-7p|%c| %m%n"
  log_ocular: false
  logger:
    net.metrosystems.ai:
      level: ERROR
    org.jboss.modules:
      level: ERROR
    com.arjuna:
      level: ERROR
  rotate_by: time
  rotate_size: 50K
  max_backup_index: 8
```

Notes:

    For 'time' rotation there is a limit of maximum 500MB for all log files.
    If no filesize is specified then 50MB is used as a default value.
    If max_backup_index is missing then 10 is used as a default value.

Other examples for file sizing:

    10 files (max_backup_index) with 10K rotate_size -> then the total amount of log files will be 50KB
    8 files (max_backup_index) with 10M rotate_size -> then the total amount of log files will be 80MB
    5 files (max_backup_index) with 20M rotate_size -> then the total amount of log files will be 100MB
    6 files (max_backup_index) with 30M rotate_size -> then the total amount of log files will be 180MB
    7 files (max_backup_index) with 30M rotate_size -> then the total amount of log files will be 210MB
    12 files (max_backup_index) with 1M rotate_size -> then the total amount of log files will be 12MB
    15 files (max_backup_index) with 8K rotate_size -> then the total amount of log files will be 120KB
    12 files (max_backup_index) with 60M rotate_size -> then the total amount of log files will be 480MB -> 8 files with 60MB each

### Prometheus Endpoint

In this container, a prometheus endpoint "nlighten/wildfly_exporter" is already installed. These metrics can be accessed via the admin port. The Wildfly metrics can be requested via Prometheus or any other tool using

```
http://localhost:9990/metrics
```

For a Prometheus environment, the following scrape config in this example is best practice:

```yaml
- job_name: apptest
  honor_timestamps: true
  scrape_interval: 5s
  scrape_timeout: 5s
  metrics_path: /metrics
  scheme: http
  static_configs:
  - targets:
    - apptest.apptest.svc.cluster.local:9990

```

In this example a kubernetes deployment is used. The target hostname references to a kubernetes service. The naming convention here is ```SERVICE_NAME.NAMESPACE_NAME.svc.cluster.local:PORT_NUMBER```

### Example to create a container running an application

As you see, it is quite simple to deploy an application. Create a Dockerfile like this

```dockerfile
FROM registry.metroscales.io/asm/wildfly:13.0

COPY apptest.war /opt/application/java/
COPY metro.jpg /opt/data/metro.jpg
```

Now build the application docker image like

```sh
docker build -t registry.metroscales.io/[YOURPROJECTNAME]/[YOURIMAGENAME]:[YOUR_VERSION_TAG]  .
```

After the application container is build, start the container on cmdline:

```sh
docker run -d --rm -p 8080:8080 -p 9990:9990 -e JVM_PARAM="-Xms2048m -Xmx2048m" -e CONFIG_TYPE=standalone-ha -e JBOSS_PWD=mysecretpassword -v $PWD/appconfig/data-source.yml:/opt/application/appconfig/data-source.yml -v $PWD/appconfig/resourceadapter.yml:/opt/application/appconfig/resourceadapter.yml -v $PWD/appconfig/loggingprofile.yml:/opt/application/appconfig/loggingprofile.yml registry.metroscales.io/[YOURPROJECTNAME]/[YOURIMAGENAME]:[YOUR_VERSION_TAG]
```

Alternatively you can use a docker-compose. For this, create a file called docker-compose.yml with the following content:

```yml
version: '3'

services:

  appserver:
    image: registry.metroscales.io/[YOURPROJECTNAME]/[YOURIMAGENAME]:[YOUR_VERSION_TAG]
    ports:
      - 0.0.0.0:8080:8080
      - 0.0.0.0:9990:9990
    restart: always
    volumes:
      - ./data-source.yml:/opt/application/appconfig/data-source.yml
      - ./resourceadapter.yml:/opt/application/appconfig/resourceadapter.yml
      - ./loggingprofile.yml:/opt/application/appconfig/loggingprofile.yml
    environment:
      - JVM_PARAM=-Xms2048m -Xmx2048m
      - CONFIG_TYPE=standalone-ha
      - JBOSS_PWD=mysecretpassword
```

Now switch to the directory where this file is created in and simply run

```sh
docker-compose up -d
```

Now your application is up and running and can be accessed using the URL http://[HOSTNAME]:8080/[CONTEXTROOT] .
The Admin console WebUI can be accessed using the URL http://[HOSTNAME]:9990/

### Customize a running container and create a new one of it
---

When you started your container, you can change settings inside of it using the WebUI or connecting to it via "docker exec -it". Test you changes in your running container and if everything works as expected, you can create a new image of it with the command

```sh
docker commit -a [MAINTAINER] [CONTAINERID] registry.metroscales.io/[PROJECTNAME]/[REPOSITORY]:[TAG]

# example of it

docker commit -a mannis.test@metronom.com db9820233935 registry.metroscales.io/asm/apptest-mk-test-1:1.0
```

Now you have persisted your changes in a new container and you can push this image into the Docker registry to be used on different nodes.
