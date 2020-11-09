while true
do
  if [ -f /opt/jboss/standalone/log/server.log ]; then
    if [  $(grep "started in" /opt/jboss/standalone/log/server.log | wc -l ) -gt 0 ]; then
	    exit
    fi
  fi  
  sleep 5
done