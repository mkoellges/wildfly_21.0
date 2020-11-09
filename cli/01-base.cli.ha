echo "*** Setting Base Parameters ***"

/subsystem=undertow:write-attribute(name=statistics-enabled,value=true)
/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=record-request-start-time,value=true)
/subsystem=undertow/server=default-server/ajp-listener=ajp:write-attribute(name=record-request-start-time,value=true)
/subsystem=undertow/server=default-server/https-listener=https:write-attribute(name=record-request-start-time,value=true)
/subsystem=undertow:write-attribute(name=statistics-enabled, value=true)
/subsystem=transactions:write-attribute(name=statistics-enabled,value=true)
/subsystem=webservices:write-attribute(name=statistics-enabled,value=true)

/subsystem=datasources/data-source=ExampleDS:write-attribute(name=statistics-enabled,value=true) 

/subsystem=ee/:write-attribute(name=global-modules,value=[{"name" => "nl.nlighten.prometheus.wildfly", "meta-inf" => "true", "services" => "true"}])
