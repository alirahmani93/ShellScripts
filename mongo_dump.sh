docker exec  -t mongo /usr/bin/mongodump  -u admin -p admin --authenticationDatabase admin --out /$(date +"%Y-%m-%d")
docker cp mongo:/$(date +"%Y-%m-%d") ~/mongo_backup_file
#chmod -R  755   ~/mongo_backup_file/$(date +"%Y-%m-%d")
rsync -Pav -e "ssh -y -i ~/mongo_backup_file/nor -p 22"  ~/mongo_backup_file/$(date +"%Y-%m-%d")    user@157.119.191.167:~/app_X_dump/mongo
rm -rf ~/mongo_backup_file/$(date +"%Y-%m-%d")
