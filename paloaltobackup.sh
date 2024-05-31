#!/bin/bash

#Script to backup Palo Alto via API with minimal dependencies.
#See the following for an overview of how to generate the API Key
#https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000Cm7yCAC

#This script will email a backup result message when completed.
#It will also log script runs in the logs folder

#This script should email out a success or failure message on every run. 
#It can be configured to run under cron tab.  Example:  
#16 5 * * * paloaltobackup cd /home/paloaltobackup;./paloaltobackup.sh >  /dev/null 2>&1

#Setup. Put this script in a folder. Make a folder 'backup', and 'logs' that the script 
#user will be able to write to.  


###########Required Variables#############
#devices.csv is a list of devices, one per line, either IP or hostname, then key.  Example
#hostname.or.ip,LUFRPTOxfljealsdlgahadlaihflasehflsadhflasdfhlsdhfiaeshdfasdfas==
#Make sure this can only be read by the script user!
devicelist="devices.csv"
#Number of days to keep configs.
keepdays=700
#addresses for mail. The mail command will need to be configured.
mailto="to@example.com"
mailfrom="from@example.com"
############End Required Variables########





#folder and date for storage
date="$(date +%Y%m%d-%H%M%S)"
folder="backup"
logfile="logs/backuplog.log"
tmplogfile="logs/$date-backuplog.log"

#Default subject is for failure, override on success
subject="Palo Backup $date Failed"
failedrun=false
while IFS=, read -r device apikey
do
        file="$folder/$device-$date.xml"
        curl -s -k "https://$device/api/?type=config&action=show&key=$apikey" --output $file

        if [ ! -f $file ]; then
                printf "$backup file not created.  Check script or connectivity\n"  | tee -a "$tmplogfile"
                failedrun=true
        else
                if grep -q "response status=\"success\"" "$file";
                then
                        printf "\n$date $device API call successfull, file $file \n" | tee -a "$tmplogfile"
                        printf "$date $device File Info " | tee -a "$tmplogfile"
                        ls -g -o $file  | tee -a "$tmplogfile"
                        printf "$date $device Zip Info " | tee -a "$tmplogfile"
                        zip "$file.zip" "$file" | tee -a "$tmplogfile"
                        rm "$file"
                else
                        printf "$date $device reachable but API Call failed - perhaps invalid API Key?\n" | tee -a "$tmplogfile"
                        failedrun=true
                fi
        fi

done < $devicelist

if [ "$failedrun" = true ] ; then
        subject="Palo Backup $date Failed"
else 
        subject="Palo Backup $date Success"
fi


printf "$date $device Removing Old Files\n " | tee -a "$tmplogfile"
find -wholename "./$folder/*.zip" -mtime +$keepdays -type f -delete -print | tee -a "$tmplogfile"

#append templogfile to permanent log and the mail/delete the current run logs
cat "$tmplogfile" >> "$logfile"
mail -r "$mailfrom" -s "$subject" "$mailto" < "$tmplogfile"
rm "$tmplogfile"
