#!/bin/bash
date=$(date +"%Y-%m-%d")
docker exec -t postgres pg_dumpall  -U postgres  > ~/postgres-backup/$date.sql
rsync -Pav -e "ssh -i ~/postgres-backup/nor"   ~/postgres-backup/$(date +"%Y-%m-%d").sql    user@IP:~/app_X_dump/postgres
rm -rf ~/postgres-backup/$(date +"%Y-%m-%d").sql
