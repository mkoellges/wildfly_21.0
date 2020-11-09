#!/bin/sh
##############################################
# insert-loggingprofile.sh
##############################################
# Script to add logging profiles from a Logging Profile yml file.
# The file must be exactly named "loggingprofiles.yml"
# The content will be written in the CLI file "04-loggingprofile.cli" so that it can
# be executed at startup
# Restrictions:
# - the indentation must be made with 2 spaces for each level
# - the parameters values must not contain the next symbols: §±!
# - the loggers' definitions must be in sequence (one after one)
# - the max_backup_index value must be an integer
##############################################
#
# Author: Valentin Nedelcu
# Modifications:
# version 01.01 - 2019.06.05 Creation of script file for time rotation
# version 01.02 - 2019.06.19 Creation of script file for size rotation
# version 01.03 - 2020.05.14 Configure the deletion of log files for 'time' rotation; keep 10 log files; use crontab job
# version 01.04 - 2020.05.27 Configure the deletion of log files for 'time' rotation; use a periodic-size-rotating-file-handler; take out crontab job
# version 01.05 - 2020.06.03 Configure the deletion of log files for 'time' rotation -> mx size is 500MB 
##############################################

vgstr_PathInput="/opt/application/appconfig"                        # can be an ENV value from Wildfly script; must be /opt/application/appconfig
vgstr_PathOutput="/opt/jboss/batch"                                 # can be an ENV value from Wildfly script; must be /opt/jboss/batch 
vgstr_YML_FileLoggingInput="loggingprofile.yml"
vgstr_CLI_FileLoggingOutput="04-loggingprofile.cli"
vgstr_CLI_LoggerOutput="tmpLoggerOutput.sh"
vgstr_LogFileOutput="logLoggingProfile.txt"                      # used for local debug of this script
vgstr_Prefix="§"                                                 # used to be placed fields
vgstr_SpaceChar="!"                                              # used to replace spaces inside value's fields
vgstr_DelimiterChar="±"                                          # used to separate fields names
# declare -a vgstr_ParamshortName

         # vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("±")}
# YML File parser -> saves whole file in memory structure
parse_yaml() {
   # local prefix=$2
   # local prefix=$vgstr_Prefix
   local s='[[:space:]]*' w='[a-zA-Z0-9\_\.]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("'$vgstr_DelimiterChar'")}
         printf("%s%s%s=\"%s\"\n", "'$vgstr_Prefix'",vn, $2, $3);
      }
   }'
}

# initializing default values; used for?!??
set_defaults() {
   :
}


fnc_WriteLogger_toFile() {
   local pstr_LoggerName="$1"
   local pstr_LoggerLevel="$2"
   local vlstr_Logger_Text=""
   local vlstr_LoggerParentList="org.jboss com.arjuna org.apache sun.rmi jacorb"

   # vlstr_ParentList="!!($pstr_LoggerName =~ /^(org\.jboss|com\.arjuna|org\.apache|sun\.rmi|jacorb)($|\.)/)"   #not ok

   vlstr_ParentList="false"

   vlnum_CountPattern1=$(echo "$pstr_LoggerName" | grep -bo "org.jboss" | sed 's/:.*$//')
   vlnum_CountPattern2=$(echo "$pstr_LoggerName" | grep -bo "com.arjuna" | sed 's/:.*$//')
   vlnum_CountPattern3=$(echo "$pstr_LoggerName" | grep -bo "org.apache" | sed 's/:.*$//')
   vlnum_CountPattern4=$(echo "$pstr_LoggerName" | grep -bo "sun.rmi" | sed 's/:.*$//')
   vlnum_CountPattern5=$(echo "$pstr_LoggerName" | grep -bo "jacorb" | sed 's/:.*$//')
   # echo "vlnum_CountPattern1>>"$vlnum_CountPattern1"<< ""vlnum_CountPattern2>>"$vlnum_CountPattern2"<< ""vlnum_CountPattern3>>"$vlnum_CountPattern3"<< "

   if [ "$vlnum_CountPattern1" = "0" ] || [ "$vlnum_CountPattern2" = "0" ] || [ "$vlnum_CountPattern3" = "0" ] || [ "$vlnum_CountPattern4" = "0" ] || [ "$vlnum_CountPattern5" = "0" ]; then
      vlstr_ParentList="true"
   fi

   vlstr_Logger_Text="/subsystem=logging/logging-profile=${vgstr_LogName}/logger=${pstr_LoggerName}:add(level=${pstr_LoggerLevel}, handlers=[${vgstr_LogName}_handler], use-parent-handlers=${vlstr_ParentList})\n"    # ok with true or false
   # vlstr_Logger_Text="/subsystem=logging/logging-profile=${vgstr_LogName}/logger=${pstr_LoggerName}:add(level=${pstr_LoggerLevel}, handlers=[${vgstr_LogName}_handler], use-parent-handlers=${!!(key =~ /^(org\.jboss|com\.arjuna|org\.apache|sun\.rmi|jacorb)($|\.)/)})\n"     #not ok

   echo $vlstr_Logger_Text >> $vgstr_PathOutput/$vgstr_CLI_LoggerOutput   
}

fnc_Power() {
   local pnum_Base=$1
   local pnum_Power=$2

   vgnum_PowerNumber=1
   # while [ $i -lt $pnum_Power ]
   i=1
   while [ $i -le $pnum_Power ]
   do
      vgnum_PowerNumber=$(($vgnum_PowerNumber*$pnum_Base))
      i=$(( i + 1 ))
   done

   # echo "vgnum_PowerNumber>>"$vgnum_PowerNumber"<<"
}

#check the rotate_size and max_backup_index parametes: Max Space Value will be 500MB
fnc_Check_Size_and_File_numbers() {

   if [ -z "$vgstr_Max_Backup_index" ] || [ "$vgstr_Max_Backup_index" = "" ] || [ "$vgstr_Max_Backup_index" = " " ]; then
      echo "NO file number value. The default value will be 10 files"
      vgstr_Max_Backup_index=10
   fi

   #take out the " chars
   vgstr_Max_Backup_index=$(echo $vgstr_Max_Backup_index | sed 's/\"//g')

   #convert upper to lower
   vgstr_Rotate_size=$(echo $vgstr_Rotate_size|tr "[:lower:]" "[:upper:]")

   if [ -z "$vgstr_Rotate_size" ] || [ "$vgstr_Rotate_size" = "" ] || [ "$vgstr_Rotate_size" = " " ]; then
      echo "NO size value. Default 50M"
      vgnum_Size=50
      vgchr_Unit="M"
   else
      #search for K, M, G inside value
      # vlnum_CountPattern2=$(echo "$vgstr_Rotate_size" | grep -bo "K" | sed 's/:.\"$//')
      # vlnum_CountPattern2=$(echo "$vgstr_Rotate_size" | grep -bo "K")
      vlnum_CountPattern2=$(echo "$vgstr_Rotate_size" | grep -bo "K" | sed 's/:.*$//')

      if [ -z "$vlnum_CountPattern2" ]; then
         vlnum_CountPattern2=$(echo "$vgstr_Rotate_size"| grep -bo "M" | sed 's/:.*$//')
         if [ -z "$vlnum_CountPattern2" ]; then
            vlnum_CountPattern2=$(echo "$vgstr_Rotate_size"| grep -bo "G" | sed 's/:.*$//')
            if [ -z "$vlnum_CountPattern2" ]; then
               echo "Unknown unit size. MB will be used by default"
               vgchr_Unit="M"
            else
               vgchr_Unit="G"
            fi
         else
            vgchr_Unit="M"
         fi
      else
         vgchr_Unit="K"
      fi

      #it doesn't work if K,M,G is not specified
      if [ -z "$vlnum_CountPattern2" ]; then
         vgnum_Size=$(echo $vgstr_Rotate_size | tr -dc '0-9')
      else
         vgnum_Size=$(echo $vgstr_Rotate_size | awk -F "$vgchr_Unit" '{print $1}' | sed 's/\"//')
      fi

      #set default size
      if [ -z "$vgnum_Size" ]; then
         echo "Unknown size value. 50 will be used by default"
         vgnum_Size=50
      fi

      # set size for KB, MB and GB
      fnc_Power 2 10
      cgnum_Kilo=$vgnum_PowerNumber

      fnc_Power 2 20
      cgnum_Mega=$vgnum_PowerNumber

      fnc_Power 2 30
      cgnum_Giga=$vgnum_PowerNumber

      # the max logs size should be 500 MB
      case $vgchr_Unit in
         "K" )
            if [ $(( $vgnum_Size*$cgnum_Kilo )) -lt $(( 500*$cgnum_Mega )) ]; then
               vgnum_Size=$(( $vgnum_Size*$cgnum_Kilo ))
            else
               vgnum_Size=$(( 500*$cgnum_Mega ))
               vgchr_Unit="M"
            fi
         ;;
         "M" )
            if [ $(( $vgnum_Size*$cgnum_Mega )) -lt $(( 500*$cgnum_Mega )) ]; then
               vgnum_Size=$(( $vgnum_Size*$cgnum_Mega ))
            else
               vgnum_Size=$(( 500*$cgnum_Mega ))
               vgchr_Unit="M"
            fi
         ;;
         "G" )
            if [ $(( $vgnum_Size*$cgnum_Giga )) -lt $(( 500*$cgnum_Mega )) ]; then
               vgnum_Size=$(( $vgnum_Size*$cgnum_Giga ))
            else
               vgnum_Size=$(( 500*$cgnum_Mega ))
               vgchr_Unit="M"
            fi
         ;;
      esac

      #calculate the number of files based on max_backup_index (the total max size is 500MB)
      vlnum_Count=$(( 500*$(($cgnum_Mega))/$vgnum_Size ))

      if [ $vlnum_Count -lt $vgstr_Max_Backup_index ]; then
         vgstr_Max_Backup_index=$vlnum_Count
      fi

      #convert againt the Size value
      case $vgchr_Unit in
         "K" )
            vgnum_Size=$(( $vgnum_Size/$cgnum_Kilo ))
         ;;
         "M" )
            vgnum_Size=$(( $vgnum_Size/$cgnum_Mega ))
         ;;
      esac
   fi
}

fnc_WriteTo_CLI_FileLoggingOutput() {
   # test if this is the first LogName -> empty LogName
   if [ "$vgstr_LogName" = "" ]; then
      :
   else   # prepare the master CLI statement
      echo "if ( outcome == success ) of /subsystem=logging/logging-profile=${vgstr_LogName}:read-resource" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      echo "  /subsystem=logging/logging-profile=${vgstr_LogName}:remove" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
#      echo "  reload" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      echo "end-if  " >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      vgstr_CLICommand="/subsystem=logging/logging-profile=${vgstr_LogName}:add()"

      echo $vgstr_CLICommand >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput

      vgstr_Formatter="$(echo ${vgstr_Formatter} | sed 's/'$vgstr_SpaceChar'/ /g')"

      #convert upper to lower
      vgstr_Rotate_by=$(echo $vgstr_Rotate_by|tr "[:upper:]" "[:lower:]")

      # if [ $vgstr_Rotate_by="time" ]; then
      if [ $vgstr_Rotate_by = '"time"' ]; then

         fnc_Check_Size_and_File_numbers

         # write the CLI command
         # vgstr_CLICommand="/subsystem=logging/logging-profile=${vgstr_LogName}/periodic-rotating-file-handler=${vgstr_LogName}_handler:add(append=true, file={path=${vgstr_LogName}.log,relative-to=${vgstr_RelativeTo}},formatter=${vgstr_Formatter}, suffix=\".yyyy.MM.dd\")\n"
         vgstr_CLICommand="/subsystem=logging/logging-profile=${vgstr_LogName}/periodic-size-rotating-file-handler=${vgstr_LogName}_handler:add(append=true, file={path=${vgstr_LogName}.log,relative-to=${vgstr_RelativeTo}},formatter=${vgstr_Formatter}, suffix=\".yyyy.MM.dd\", rotate-size=\"$vgnum_Size$vgchr_Unit\", max-backup-index=\"${vgstr_Max_Backup_index}\")\n"
      # elif [ "$vgstr_Rotate_by"="size" ]; then
      elif [ $vgstr_Rotate_by = '"size"' ]; then

         fnc_Check_Size_and_File_numbers

         # write the CLI command
         # vgstr_CLICommand="/subsystem=logging/logging-profile=${vgstr_LogName}/size-rotating-file-handler=${vgstr_LogName}_handler:add(append=true, file={path=${vgstr_LogName}.log,relative-to=${vgstr_RelativeTo}},formatter=\"${vgstr_Formatter}\", rotate-size=\"$vgnum_Size$vgchr_Unit\", max-backup-index=\"$vgstr_Max_Backup_index\")\n"
         vgstr_CLICommand="/subsystem=logging/logging-profile=${vgstr_LogName}/size-rotating-file-handler=${vgstr_LogName}_handler:add(append=true, file={path=${vgstr_LogName}.log,relative-to=${vgstr_RelativeTo}},formatter=${vgstr_Formatter}, rotate-size=\"$vgnum_Size$vgchr_Unit\", max-backup-index=\"$vgstr_Max_Backup_index\")\n"
      else
         echo "Unknown rotation method: ${vgstr_Rotate_by}"
      fi

      echo $vgstr_CLICommand >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
   fi

   cat $vgstr_PathOutput/$vgstr_CLI_LoggerOutput>> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
   echo "/subsystem=logging/file-handler=${vgstr_LogName}_log:add(file={\"path\"=>\"${vgstr_LogName}.log\", \"relative-to\"=>\"jboss.server.log.dir\"})" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput

   > $vgstr_PathOutput/$vgstr_CLI_LoggerOutput

   # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput

}

# Check if Loggin Profile yml file exist
if [ -f $vgstr_PathInput/$vgstr_YML_FileLoggingInput ]; then

   # Empty the files and variables
   > $vgstr_PathOutput/$vgstr_LogFileOutput
   > $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
   > $vgstr_PathOutput/$vgstr_CLI_LoggerOutput

   echo 'echo "*** Configure logging profile(s) ***"' >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput

   vgstr_CLICommand=""
   vgstr_ConnectionDefText=""
   vgstr_LogName=""
   vgnum_LogNumbers=0
   vgstr_LogginDeffinitionString1=""
   vgstr_LogginDeffinitionString2=""
   vgstr_LogginDeffinitionString3=""
   vgstr_Rotate_size=""

   vgstr_LogginDeffinitionString1="$(parse_yaml $vgstr_PathInput/$vgstr_YML_FileLoggingInput)"
   vgstr_LogginDeffinitionString2="$(echo ${vgstr_LogginDeffinitionString1} | sed 's/ '$vgstr_Prefix'/'$vgstr_Prefix'/g')"   # it's ok
   vgstr_LogginDeffinitionString3="$(echo ${vgstr_LogginDeffinitionString2} | sed 's/ /'$vgstr_SpaceChar'/g')"
   vgstr_LogginDeffinitionString4="$(echo ${vgstr_LogginDeffinitionString3} | sed 's/'$vgstr_Prefix'/ /g')"

   # echo "vgstr_LogginDeffinitionString4>>"$vgstr_LogginDeffinitionString4"<<vgstr_LogginDeffinitionString4"
   # echo $(parse_yaml $vgstr_PathInput/$vgstr_YML_FileLoggingInput)>> $vgstr_PathOutput/$vgstr_LogFileOutput
   # echo ${JBOSS_HOME}

   # check if we are inside an JBoss or Tomcat container
   if [ -z "${JBOSS_HOME}" ]; then
      echo "Tomcat container"
   else
      # for y in $(parse_yaml $vgstr_PathInput/$vgstr_YML_FileLoggingInput | awk -F '=' '{print $1}')
      for y in $(echo "${vgstr_LogginDeffinitionString4}" | awk -F '=' '{print $1}')    
      do
         for i in $(echo "${vgstr_LogginDeffinitionString4}" | grep $y) ; do
            vgstr_ParamLongName=$(echo $i | awk -F '=' '{print $1}'|tr "[:upper:]" "[:lower:]")
            vgstr_ParamValue=$(echo $i | awk -F '=' '{print $2}')
            vgstr_ParamValue2=$(echo $i | awk -F '=' '{val=""; for(i=2;i<NF+1;i++) val = val "=" $i; print val}')


            #I have to check if I have many ± chars -> many levels
            vgnum_CountSpecialChar=$(echo "${vgstr_ParamLongName}" | awk -F "${vgstr_DelimiterChar}" '{print NF-1}')
            # echo "vgnum_CountSpecialChar>>"$vgnum_CountSpecialChar"<<vgnum_CountSpecialChar"

            case $vgnum_CountSpecialChar in
               1 )
                  vgstr_ParamShortName1=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $1}')
                  vgstr_ParamShortName2=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $2}')
               ;;
               2 )
                  vgstr_ParamShortName1=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $1}')
                  vgstr_ParamShortName2=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $2}')
                  vgstr_ParamShortName3=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $3}')
               ;;
               3 )
                  vgstr_ParamShortName1=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $1}')
                  vgstr_ParamShortName2=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $2}')
                  vgstr_ParamShortName3=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $3}')
                  vgstr_ParamShortName4=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $4}')
               ;;
               4 )
                  vgstr_ParamShortName1=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $1}')
                  vgstr_ParamShortName2=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $2}')
                  vgstr_ParamShortName3=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $3}')
                  vgstr_ParamShortName4=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $4}')
                  vgstr_ParamShortName5=$(echo $vgstr_ParamLongName|awk -F$vgstr_DelimiterChar '{print $5}')
               ;;
            esac 

            #check if is a new Log Name
            if [ "$vgstr_ParamShortName1" != "$vgstr_LogName" ]; then
               # echo "New Logger!!!!>>"$vgstr_ParamShortName1"<< vgstr_LogName>>"$vgstr_LogName"<<"

               fnc_WriteTo_CLI_FileLoggingOutput

               vgstr_LogName=$vgstr_ParamShortName1
               vgnum_LogNumbers=$((vgnum_LogNumbers+1))
               vgstr_LoggerName=""
            else    #the same log Name
               :
            fi

            case ${vgstr_ParamShortName2} in
               "log_format" )
                  # echo $vgstr_ParamValue
                  vgstr_Formatter=$vgstr_ParamValue
                  vgstr_Formatter=$vgstr_ParamValue2
               ;;
               "log_ocular" )
                  vgstr_RelativeTo="jboss.server.log.dir"
                  if [ $vgstr_ParamValue = '"true"' ]; then 
                     vgstr_RelativeTo="ocular.log.dir"
                  fi
               ;;
               "logger" )
                  # check if a new logger is founded
                  if [ "$vgstr_ParamShortName3" != "$vgstr_LoggerName" ]; then
                     vgstr_LoggerName=$vgstr_ParamShortName3
                     vgstr_LoggerLevel=$vgstr_ParamValue

                     fnc_WriteLogger_toFile "$vgstr_LoggerName" "$vgstr_LoggerLevel"
                  fi
               ;;
               "rotate_by" )
                  vgstr_Rotate_by=$vgstr_ParamValue
               ;;
               "max_backup_index" )
                  vgstr_Max_Backup_index=$vgstr_ParamValue
               ;;
               "rotate_size" )
                  vgstr_Rotate_size=$vgstr_ParamValue
               ;;
            esac   
         done
      done
   
      fnc_WriteTo_CLI_FileLoggingOutput
      # echo "run-batch" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
      # echo "" >> $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
   
   #   Delete the temporary file
      rm $vgstr_PathOutput/$vgstr_CLI_LoggerOutput

   # used for?!??
   #   set_defaults
   fi
fi

# sed -i s/\"//g $vgstr_PathOutput/$vgstr_CLI_FileLoggingOutput
