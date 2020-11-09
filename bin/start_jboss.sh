#!/bin/bash
set -m
 
BASE="/msys/web/jboss"
OUT="/tmp"
IPADDRESS=$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
DEPLOY=false

if [ "${ETCD_NODES}" = "" ]; then

    export JAVA_OPTS="${JAVA_OPTS} ${JVM_PARAM}"

else

    ## generate CONFD folders and config files
    mkdir -p /etc/confd
    mkdir -p /etc/confd/conf.d
    touch /etc/confd/conf.d/config.toml
    cat >/etc/confd/conf.d/config.toml << EOL
[template]
src = "config.conf.tmpl"
dest = "/$OUT/config.conf"
keys = [
    "$BASE"
]
EOL

    mkdir -p /etc/confd/templates
    touch /etc/confd/templates/config.conf.tmpl
    cat >/etc/confd/templates/config.conf.tmpl << EOL
{{range gets "$BASE/*"}}{{base .Key}}=={{.Value}}
{{end}}
EOL
 
    ## append size info (passed as first arg) into the template
    if [ "${1}" = 'small' ] || [ "${1}" = 'medium' ] || [ "${1}" = 'large' ]; then
cat >>/etc/confd/templates/config.conf.tmpl << EOL
{{range gets "$BASE/$1/*"}}{{base .Key}}=={{.Value}}
{{end}}
EOL
    fi

    ## get all default and size dependend values from ETCD and write to /$OUT/config.conf
    /u01/bin/confd -onetime -backend etcd -node http://$ETCD_NODES
 
    ## overwrite default values in case a size dependend redefinition exists so that we have just the aggregated totals in the config
    while read x; do
        key=$(echo $x | awk -F'[==]' '{print $1}')
        if [ -z $key ]; then
          break
        fi
        awk /$key==/ $OUT/config.conf | tail -1 >> $OUT/temp.conf
    done <  $OUT/config.conf
 
    ## print config values to screen and cleanup
    rm $OUT/config.conf
    mv $OUT/temp.conf $OUT/config.conf
    cat $OUT/config.conf
 
    for i in $(cat /tmp/config.conf)
    do
        VALUE=` echo $i | awk -F"==" '{print $2}'`
        export JAVA_OPTS="${JAVA_OPTS} ${VALUE}"
   done
fi 

if [ "${USE_EXISTING}" = "0" ]; then
    add-user.sh admin ${JBOSS_PWD} ManagementRealm --silent=true
    add-user.sh -a -u jolokia jolokia -g jolokia --silent=true

    for i in standalone.xml standalone-ha.xml standalone-full.xml standalone-full-ha.xml
    do
        sed -i "s|<location name=\"/\" handler=\"welcome-content\"/>|<location name=\"/\" handler=\"welcome-content\"/>\n                    <location name=\"/mydata\" handler=\"mydata\"/>|" /opt/jboss/standalone/configuration/$i
        sed -i "s|<file name=\"welcome-content\" path=\"\${jboss.home.dir}/welcome-content\"/>|<file name=\"welcome-content\" path=\"\${jboss.home.dir}/welcome-content\"/>\n                <file name=\"mydata\" path=\"/opt/data\" directory-listing=\"false\"/>|" /opt/jboss/standalone/configuration/$i
    done

    # create cli script to delete old datasources and add new ones
    /opt/jboss/bin/insert-datasource.sh >> /tmp/insert-datasource.log 2>&1

    # add resource adaptors
    /opt/jboss/bin/insert-resourceadapter.sh >> /tmp/insert-resourceadapter.log 2>&1

    # add resource adaptors
    /opt/jboss/bin/insert-loggingprofile.sh >> /tmp/insert-loggingprofile.log 2>&1

    # create cli script to deploy applications if there
    /opt/jboss/bin/deploy.sh >> /tmp/insert-deploy.log 2>&1
else
#    /opt/jboss/bin/jboss-cli.sh --connect ":shutdown" 
    rm -rf /opt/jboss/standalone/configuration/standalone_xml_history/current
fi

echo
echo
echo
echo "start Wildfly using:"
echo
echo "standalone.sh -c ${CONFIG_TYPE}.xml -Djboss.bind.address=0.0.0.0 -Djboss.bind.address.management=0.0.0.0 -Djboss.bind.address.private=${IPADDRESS} -u ${MCASTADDRESS}"
echo
echo

standalone.sh -c ${CONFIG_TYPE}.xml -Djboss.bind.address=0.0.0.0 -Djboss.bind.address.management=0.0.0.0 -Djboss.bind.address.private=${IPADDRESS} -u ${MCASTADDRESS} &

# create check.html file
echo "Ich bin die MidTier ${HOSTNAME}" > /opt/jboss/welcome-content/check.html

# wait until server is up and running
/opt/jboss/bin/wait_for_server_is_running.sh

echo "" > /opt/jboss/batch/run.cli-main

if [ "${USE_EXISTING}" = "0" ]; then
    if [ "${CONFIG_TYPE}" = "standalone" ] || [ "${CONFIG_TYPE}" = "standalone-full" ]; then
        mv /opt/jboss/batch/01-base.cli.single /opt/jboss/batch/01-base.cli
        rm /opt/jboss/batch//01-base.cli.ha
    else
        mv /opt/jboss/batch/01-base.cli.ha /opt/jboss/batch/01-base.cli
        rm /opt/jboss/batch/01-base.cli.single
    fi

    for i in $(ls /opt/jboss/batch/*.cli ); do
      cat $i >> /opt/jboss/batch/run.cli-main
      echo "" >> /opt/jboss/batch/run.cli-main
    #  jboss-cli.sh --connect --file=$i
    done
else
    cat /opt/jboss/batch/01-base.cli >> /opt/jboss/batch/run.cli-main
fi

jboss-cli.sh --connect --timeout=30000  --command-timeout=300 --file=/opt/jboss/batch/run.cli-main | tee /tmp/responsefile.log

if [ $(cat /tmp/responsefile.log | grep "Unrecognized arguments" | wc -l ) -ne 0 ]; then
    exit 1
fi
if [ $(cat /tmp/responsefile.log | grep "WFLYCTL0062" | wc -l ) -ne 0 ]; then
    exit 2
fi

fg %1
