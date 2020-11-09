#!/bin/sh
##############################################
# insert-resourceadapter.sh
##############################################
# Script to add resource adapters from definition from a Resource Adapter yml file.
# The file must be exactly named "resourceadapter.yml"
# The content will be written in the CLI file "05-resourceadapter.cli" so that it can
# be executed at startup
# Restrictions:
# - the entire structure must be declared (mq_adapter_name, mq_connectionfactory_name)
# - mq_adapter_name: - must be on the first line of a group definition
# - mq_connectionfactory_name - must be declared before their child properties
##############################################
#
# Author: Valentin Nedelcu
# Modifications:
# version 01.01 - 2019.04.14 Creation of script file
# version 01.02 - 2019.04.25 Changing string manipulation in order to work on sh/Ubuntu containers
# version 01.03 - 2019.05.06 Change the destination of the input yml file -> appconfig folder
# version 01.04 - 2019.05.07 Change the order of lines inside generated CLI -> deploy rar file first
# version 01.05 - 2019.05.13 The creation steps are done in one batch step 
##############################################

# vgstr_PathInput="/was/tmp"                                        # can be an ENV value from Wildfly script; for local tests: /was/tmp
# vgstr_PathOutput="/was/tmp"                                       # can be an ENV value from Wildfly script; for local tests: /was/tmp
vgstr_PathInput="/opt/application/appconfig"                        # can be an ENV value from Wildfly script; must be /opt/application/appconfig
vgstr_PathOutput="/opt/jboss/batch"                                 # can be an ENV value from Wildfly script; must be /opt/jboss/batch 
vgstr_YML_FileResourceInput="resourceadapter.yml"
vgstr_CLI_FileResourceOutput="05-resourceadapter.cli"
vgstr_CLI_FileConnPropOutput="ConnectionsProperties.cli"
vgstr_LogFileOutput="logResourceAdapter.txt"                      # used for local debug of this script

# YML File parser -> saves whole file in memory structure
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9\_]*' fs=$(echo @|tr @ '\034')

   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("%")}
         printf("%s%s%s&\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# initializing default values; used for?!??
set_defaults() {
   transaction-support="NoTransactions"
   min-pool-size=1
   max-pool-size=10
}

# check the last 2 chars if are ()
fnc_CheckLast2Chars() {
   local pstr_Text="$1"
   local pstr_Section="$2"
   local vlnum_length
   local vlstr_last2chars
   local vlstr_shortString
   local vlstr_endString

   # take the last 2 characters
   vlnum_length=$((${#pstr_Text}-1))
   vlstr_last2chars=$(expr substr ${pstr_Text} $vlnum_length 2)
   vlstr_shortString=$(expr substr $pstr_Text 1 $vlnum_length)
   vlstr_endString=",)"

   # chechk if this is the first attribute
   # if [ "${pstr_Text:${vlnum_length}:2}" != "()" ]; then
   if [ ${vlstr_last2chars} != "()" ]; then
      case $pstr_Section in
      "Header" )
          vgstr_HeaderText="${vlstr_shortString}${vlstr_endString}"
      ;;
      "ConnectionDef" )
         vgstr_ConnectionDefText="${vlstr_shortString}${vlstr_endString}"
      ;;
      esac
   fi
}

# add a new parameter to string Text
fnc_AddParameter() {
   local pstr_Text="$1"
   local pstr_ParameterName="$2"
   local pstr_ParameterValue="$3"
   local pstr_Section="$4"
   local vlnum_length
   local vlstr_shortString
   local vlstr_endString

   # replace the last ) with a new parameter
   vlnum_length=$((${#pstr_Text}-1))

   vlstr_endString="${pstr_ParameterName}=${pstr_ParameterValue})"
   vlstr_shortString=$(expr substr "$pstr_Text" 1 $vlnum_length)

   case $pstr_Section in
      "Header" )
         vgstr_HeaderText="${vlstr_shortString}${vlstr_endString}"
      ;;
      "ConnectionDef" )
         vgstr_ConnectionDefText="${vlstr_shortString}${vlstr_endString}"
      ;;
   esac
}

fnc_WriteConnProp_toFile() {
   local pstr_Text="$1"
   local pstr_Value="$2"
   local vlstr_ConnectionProp_Text=""

   vlstr_ConnectionProp_Text="/subsystem=resource-adapters/resource-adapter=${vgstr_Adapter_name=}/connection-definitions=${vgstr_Connection_name}/config-properties=$pstr_Text:add(value=$pstr_Value)"
   echo $vlstr_ConnectionProp_Text >> $vgstr_PathOutput/$vgstr_CLI_FileConnPropOutput   
}

fnc_WriteTo_CLI_FileResourceOutput() {
   # deploy the file
   echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   # echo "deploy --force /opt/application/appconfig/"$(echo ${vgstr_Adapter_archive} | sed 's/\"//g' ) >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   echo "deploy --force $vgstr_PathInput/"$(echo ${vgstr_Adapter_archive} | sed 's/\"//g' ) >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput

   echo "batch" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput

   echo $vgstr_HeaderText >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   echo $vgstr_ConnectionDefText >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput

   cat $vgstr_PathOutput/$vgstr_CLI_FileConnPropOutput>> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput

   echo "/subsystem=resource-adapters/resource-adapter=${vgstr_Adapter_name}:activate" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   echo "run-batch" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
}

# Check if Reource Adapter yml file exist
if [ -f $vgstr_PathInput/$vgstr_YML_FileResourceInput ]; then

   # Empty the files and variables
   > $vgstr_PathOutput/$vgstr_LogFileOutput
   > $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
   > $vgstr_PathOutput/$vgstr_CLI_FileConnPropOutput

   vgstr_HeaderText=""
   vgstr_ConnectionDefText=""
   vgstr_Adapter_name=""
   vgstr_Adapter_archive=""
   vgstr_Connection_name=""
  
   for y in $(parse_yaml $vgstr_PathInput/$vgstr_YML_FileResourceInput | awk -F '%' '{print $1}')
   do

      RA_PARAM_NAME=$(echo $y | awk -F '&' '{print $1}'|tr "[:upper:]" "[:lower:]")
      RA_PARAM_VALUE=$(echo $y | awk -F '&' '{print $2}')
      
      case ${RA_PARAM_NAME}  in
         "mq_adapter_name"    )
         #check if I have multiple resource adapters
            if [ "$vgstr_HeaderText" != "" ]; then
               fnc_WriteTo_CLI_FileResourceOutput

               # Clear date for the next resource adapter
               vgstr_HeaderText=""
               vgstr_ConnectionDefText=""
               > $vgstr_PathOutput/$vgstr_CLI_FileConnPropOutput
            fi
            vgstr_Adapter_name="$RA_PARAM_VALUE"

            # Remove the existing adapter and add recreate the new one
            echo "if ( outcome == success ) of /subsystem=resource-adapters/resource-adapter=${RA_PARAM_VALUE}:read-resource" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
            echo "  /subsystem=resource-adapters/resource-adapter=${RA_PARAM_VALUE}:remove" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
            echo "  reload" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
            echo "end-if  " >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
            echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
            vgstr_HeaderText="/subsystem=resource-adapters/resource-adapter=$RA_PARAM_VALUE:add()"
         ;;

         "mq_adapter_archive"    )
            fnc_CheckLast2Chars "$vgstr_HeaderText" "Header"
            # fnc_AddParameter "$vgstr_HeaderText" "archive" "$RA_PARAM_VALUE" "Header" # error
            # fnc_AddParameter "$vgstr_HeaderText" "archive" "$vgstr_PathInput/$RA_PARAM_VALUE" "Header" # error
            fnc_AddParameter "$vgstr_HeaderText" "archive" "$(echo $RA_PARAM_VALUE | sed 's/\"//g' )" "Header"
            vgstr_Adapter_archive=$RA_PARAM_VALUE
         ;;

         "mq_adapter_transaction_support"    )
            fnc_CheckLast2Chars "$vgstr_HeaderText" "Header"
            fnc_AddParameter "$vgstr_HeaderText" "transaction-support" "$RA_PARAM_VALUE" "Header"
         ;;

         "mq_connectionfactory_name"    )
            if [ "$vgstr_ConnectionDefText" != "" ]; then
               echo $vgstr_ConnectionDefText >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
               echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
               vgstr_ConnectionDefText=""
            fi
            vgstr_Connection_name="$RA_PARAM_VALUE"
            vgstr_ConnectionDefText="/subsystem=resource-adapters/resource-adapter=${vgstr_Adapter_name=}/connection-definitions=${RA_PARAM_VALUE}:add(class-name=\"com.ibm.mq.connector.outbound.ManagedConnectionFactoryImpl\",use-ccm=true,enabled=true,use-java-context=true)"
         ;;

         "mq_connectionfactory_jndi_name"    )
            fnc_CheckLast2Chars "$vgstr_ConnectionDefText" "ConnectionDef"
            fnc_AddParameter "$vgstr_ConnectionDefText" "jndi-name" "$RA_PARAM_VALUE" "ConnectionDef"
         ;;

         "mq_connectionfactory_pool_min"    )
            fnc_CheckLast2Chars "$vgstr_ConnectionDefText" "ConnectionDef"
            fnc_AddParameter "$vgstr_ConnectionDefText" "min-pool-size" "$RA_PARAM_VALUE" "ConnectionDef"
         ;;

         "mq_connectionfactory_pool_max"    )
            fnc_CheckLast2Chars "$vgstr_ConnectionDefText" "ConnectionDef"
            fnc_AddParameter "$vgstr_ConnectionDefText" "max-pool-size" "$RA_PARAM_VALUE" "ConnectionDef"
         ;;

         "mq_connectionfactory_connection_name_list" )
            fnc_WriteConnProp_toFile "connectionNameList" "$RA_PARAM_VALUE"
         ;;

         "mq_connectionfactory_transporttype" )
            fnc_WriteConnProp_toFile "transportType" "$RA_PARAM_VALUE"
         ;;
   
         "mq_queue_manager" )
            fnc_WriteConnProp_toFile "queueManager" "$RA_PARAM_VALUE"
         ;;

         "mq_channel_name" )
            fnc_WriteConnProp_toFile "channel" "$RA_PARAM_VALUE"
         ;;

      esac
   done
  
   fnc_WriteTo_CLI_FileResourceOutput

#   Delete the temporary file
   rm $vgstr_PathOutput/$vgstr_CLI_FileConnPropOutput

# used for?!??
#   set_defaults
fi

# sed -i s/\"//g $vgstr_PathOutput/$vgstr_CLI_FileResourceOutput
