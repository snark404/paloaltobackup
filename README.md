## Palo Alto Backup
Simple script to backup via API and send email report of status / size of backup.  

Script takes a list of devices in devices.csv and gets a configuration from each of them via HTTP API (see https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000Cm7yCAC ).  Edit the config.sh to set email addresses and number of files saved.

Script will then compare that to the last retrieved copy and save a timestamped copy if it is different. The script will also do a clean up to remove config copies older than x days, but only if there are at least a minimum number of revisions present. A copy of the current config is stored in the backup folder as devicename-tmp.xml and a copy of the diff is stored as devicename-tmp.diff.

Run the script via crontab with something like
```
   16 5 * * * paloaltobackup cd /home/paloaltobackup;./paloaltobackup.sh >  /dev/null 2>&1
```

Script will email a report every time is it run.  The script does not send out the file changes to avoid security issues, but does send out a summary of changes.  An example email will look like:

```
**Subject**:Palo Backup 20250429-051601 Success

20250429-051601 router.example.com API call successfull
Added / Deleted / Total Lines / Sections:  154 /   0 / 154 /  5
   adding: backup/router.example.com-20250429-051601.xml (deflated 90%)

20250429-051601 192.168.1.1 API call successfull No changes

20250429-051601 Removing Zip Files older than 200 days old for router.example.com

./backup/router.example.com-20241010-051601.xml.zip
```
