#!/bin/bash

#Script to backup Palo Alto via API.
#See the following for an overview of how to generate the API Key
#https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000Cm7yCAC

#This script should email out a success or failure message on every run. 
#It can be configured to run under cron tab.  Example:  
#16 5 * * * paloaltobackup cd /home/paloaltobackup;./paloaltobackup.sh >  /dev/null 2>&1

#Setup:
#Put this script in a folder. Make a folder 'backup', and 'logs' that the script 
#user will be able to write to. config.sh will hold emails and other private config elements.
#devices.csv will hold a list of devices and credentials. 


source config.sh


#Default subject is for failure, override on success
subject="Palo Backup $date Failed"
failedrun=false
while IFS=, read -r device apikey
do
        file="$folder/$device-$date.xml"
        tmpfile="$folder/$device-tmp.xml"
        difffile="$folder/$device-tmp.diff"
        curl -s -k "https://$device/api/?type=config&action=show&key=$apikey" --output $file

        if [ ! -f $file ]; then
                printf "\n$device backup file not created.  Check script or connectivity\n"  | tee -a "$tmplogfile"
                failedrun=true
        else
                if grep -q "<response status=\"success\"><result>" "$file";
                then
                        printf "\n$date $device API call successfull \n" | tee -a "$tmplogfile"
                        #Remove response/result wrapper from the api call
                        sed -i 's/^<response status="success"><result>//' $file
                        sed -i 's/<\/result><\/response>$//' $file
                        #if tmp file exists, log some comparision stats.
                        #
                        if [ -f "$tmpfile" ]; then

                                diff -u -s "$tmpfile" "$file" > "$difffile" 
                                if  grep -q ' are identical' "$difffile" ; then
                                        echo "No changes"  | tee -a "$tmplogfile"
                                else

                                        add_lines=$(cat "$difffile" | grep ^+ | wc -l)
                                        del_lines=$(cat "$difffile" | grep ^- | wc -l)

                                        #Get number of sections by counting lines with @@
                                        section_lines=$(cat "$difffile" | grep ^@@ | wc -l)

                                        # subtract header lines from count (those starting with +++ & ---) 
                                        add_lines=$(expr $add_lines - 1)
                                        del_lines=$(expr $del_lines - 1)
                                        total_change=$(expr $add_lines + $del_lines)

                                        printf "Added / Deleted / Total Lines / Sections:  " | tee -a "$tmplogfile"
                                        printf "%3s / " "$add_lines" | tee -a "$tmplogfile"
                                        printf "%3s / " "$del_lines" | tee -a "$tmplogfile"
                                        printf "%3s /" "$total_change" | tee -a "$tmplogfile"
                                        printf "%3s \n " "$section_lines" | tee -a "$tmplogfile"
                                        zip "$file.zip" "$file" | tee -a "$tmplogfile"

                                fi
                                #rm "$difffile"

                        else
                                echo "No file for comparision, Saving new file"
                                printf "$date $device File Info " | tee -a "$tmplogfile"
                                ls -g -o $file  | tee -a "$tmplogfile"
                                printf "$date $device Zip Info " | tee -a "$tmplogfile"
                                zip "$file.zip" "$file" | tee -a "$tmplogfile"
                        fi
                        #Make new temp file that will be used for comparisions next time
                        mv "$file" "$tmpfile"
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

#For each device if files greater than minfiles and older than keepdays delete files
while IFS=, read -r device apikey
do
        file_count=$(find -wholename "./$folder/$device*.zip" -type f -print | wc -l)
        if [ "$file_count" -gt $minfiles ]; then
                delete_count=$(find -wholename "./$folder/$device*.zip" -mtime +$keepdays -type f -print | wc -l)
                if [ "$delete_count" -gt 0 ]; then
                       printf "\n$date Removing Zip Files older than $keepdays days old for $device\n\n" | tee -a "$tmplogfile"
                       find -wholename "./$folder/$device*.zip" -mtime +$keepdays -type f -delete -print | tee -a "$tmplogfile"
                fi
#       else
#               printf "\n$date Less than $minfiles files for $device, skipping clean up\n" | tee -a "$tmplogfile"
        fi
done < $devicelist

#append templogfile to permanent log and the mail/delete the current run logs
cat "$tmplogfile" >> "$logfile"
mail -r "$mailfrom" -s "$subject" "$mailto" < "$tmplogfile"
rm "$tmplogfile"
