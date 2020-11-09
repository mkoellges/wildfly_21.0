# if [ -f /opt/application/java/*.jar ] ||  [ -f /opt/application/java/*.war ] || [  -f /opt/application/java/*.ear ]; then
#   echo "batch" > /opt/jboss/batch/90-deploy.cli
# fi

if compgen -G  "/opt/application/java/*.jar" > /dev/null ; then
  for i in /opt/application/java/*.jar; do
      echo "deploy ${i}" >> /opt/jboss/batch/90-deploy.cli
  done
fi

if compgen -G  "/opt/application/java/*.war" > /dev/null ; then
  for i in /opt/application/java/*.war; do
      echo "deploy ${i}" >> /opt/jboss/batch/90-deploy.cli
  done
fi

if compgen -G  "/opt/application/java/*.ear" > /dev/null ; then
  for i in /opt/application/java/*.ear; do
      echo "deploy ${i}" >> /opt/jboss/batch/90-deploy.cli
  done
fi

# if [ -f /opt/application/java/*.jar ] || [ -f /opt/application/java/*.war ] || [ -f /opt/application/java/*.ear ]; then
#  echo "reload" >> /opt/jboss/batch/90-deploy.cli
#  echo "run-batch" >> /opt/jboss/batch/90-deploy.cli
# fi