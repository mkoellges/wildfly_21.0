echo "" > /opt/jboss/batch/02-datasource.cli
echo "" > /opt/jboss/batch/03-deploy.cli
rm /opt/application/java.ear 2>/dev/null
rm /opt/application/java.war 2>/dev/null
rm /opt/application/java.jar 2>/dev/null
rm /opt/application/appconfig/data-source.yml 2>/dev/null