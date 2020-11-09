#!/bin/bash
##############################################
# insert-datasource.sh
##############################################
# Script to add datasources from definition in a data-source.yml file.
# The file must be exactly named "data-source.yml"
# The content will be written in the file "context.yml" so that it can
# be used at startup of catalina.
##############################################
# Author: Manfred Koellges
# Version:
#   1.0    :  20.02.2018
#   2.0    :  03.04.2019 Muhammad Ali Al-Sayed Ali
##############################################

# YML File parser -> saves whole file in memory structure

parse_yaml() {
   cat $1 | grep -v "^#" |awk -F ": " '
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }
{
if( NF < 1) {} 
else if($2 =="") {
dbname=trim($1);dbname=substr(dbname,1,length(dbname)-1);name[NR]=dbname; 
line[dbname "%min-pool-size"] = 10; 
line[dbname "%max-pool-size"] = 30; 
line[dbname "%idle-timeout-minutes"] = 15; 
line[dbname "%blocking-timeout-wait-millis"] = 5000;
} 
else line[dbname "%" trim($1)] = trim($2)

}END{ 
for( a in name)
{
# print "batch"
prev_result = "data-source add --name=" name[a] " --jndi-name=java:/jdbc/" name[a]
post_result = ""
body_result = ""
if(tolower(line[name[a] "%dbtype"]) == "oracle")  post_result = " --driver-name=oracle --check-valid-connection-sql=\"select 1 from dual\""
if(tolower(line[name[a] "%dbtype"]) == "mysql")   post_result = " --driver-name=mysql"
if(tolower(line[name[a] "%dbtype"]) == "postgres")post_result = " --driver-name=postgresql"
if(tolower(line[name[a] "%dbtype"]) == "casandra")post_result = " --driver-name=cassandra --class-name=org.apache.tomcat.jdbc.pool.DataSourceFactory"

for(d in line)
{
split(d,var_x,"%")
if(name[a] == var_x[1] && var_x[2] != "dbtype") body_result = body_result " --" var_x[2] "=" line[d] 
}
# write the context file and insert the datasource
print "if ( outcome == success ) of /subsystem=datasources/data-source=" name[a] "/:read-resource___NEWLINE___" 
# print "  /subsystem=datasources/data-source=" name[a] ":disable___NEWLINE___"
print "  /subsystem=datasources/data-source=" name[a] ":remove___NEWLINE___" 
print "end-if___NEWLINE___"
print "___NEWLINE___"
print prev_result body_result post_result "___NEWLINE___"
print "___NEWLINE___" 
print "/subsystem=datasources/data-source=" name[a] ":write-attribute(name=statistics-enabled,value=true)"
print "___NEWLINE___" 
# rint "/subsystem=datasources/data-source=" name[a] "/statistics=pool:write-attribute(name=statistics-enabled,value=true)"
# print "___NEWLINE___" 
# print "/subsystem=datasources/data-source=" name[a] "/statistics=jdbc:write-attribute(name=statistics-enabled,value=true)"
# print "___NEWLINE___" 
print "___NEWLINE___" 
}
# print "run-batch"
print "___NEWLINE___" 
}
'
}

set_defaults() {
   # initializing default values
   # https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.2/html/configuration_guide/reference_material#datasource_parameters
   ## extra =" --connection-url=${URL} --jndi-name=java:/jdbc/${DBSOURCE} --user-name=${USERNAME} --password=${PASSWORD} --min-pool-size=${MINCONNECTIONS} --max-pool-size=${MAXCONNECTIONS} " 
   #oracle: connectionProperties=\"SetBigStringTryClob=true\" accessToUnderlyingConnectionAllowed=\"true\"
   echo 
}

DS_DIR="/opt/application/appconfig"
BATCH_DIR="/opt/jboss/batch"
DSTEXT=$(parse_yaml ${DS_DIR}/data-source.yml)

#echo $DSTEXT
echo ${DSTEXT} | awk -F"___NEWLINE___" '{i =0; while (i <NF) print $(++i)}' >> ${BATCH_DIR}/02-datasource.cli

# echo "reload" >> ${BATCH_DIR}/02-datasource.cli

# sed -i s/\"//g ${batch}/02-datasource.cli
