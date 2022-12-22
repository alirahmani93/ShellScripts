docker exec -it postgres_wo sh
su - postgres
pg_dump -U postgres <db_name> > ~/<name>.sql
docker cp postgres_wo:/var/lib/postgresql/<name>.sql ./<name>.sql
