# Migration from MariaDB to PostgreSQL using pgloader

Change the compose profiles to include just the databases and the server, to keep the databases in a clean state.

```shell
# add this to the server.env
COMPOSE_PROFILES=server,postgresql,mariadb
```

## Backup

Ensure you created a backup of the database using the `bluerange-backup.sh`.

## Prepare PostgreSQL

1. Switch the database configuration in the Server configuration to the PostgreSQL.
1. Start the Server once, to let it create the database schema
1. Stop the Server again before proceeding with the migration

## pgloader script

```sql
LOAD DATABASE
    FROM mysql://bluerange:<pw>@database/bluerange
    INTO postgresql://bluerange:<pw>@postgresql/bluerange
    WITH data only, truncate, quote identifiers, 
        batch rows = 10000, prefetch rows = 10000,
        workers = 2, concurrency = 1,
        multiple readers per thread, rows per range = 50000
    SET PostgreSQL PARAMETERS
        maintenance_work_mem to '128MB',
        work_mem to '12MB'
    EXCLUDING TABLE NAMES MATCHING 'DATABASECHANGELOG', 'DATABASECHANGELOGLOCK', 'SCHEDULER_LOCK', 'JGROUPSPING'
    ALTER SCHEMA 'bluerange' RENAME TO 'public'
;
```

```shell
# start pgloader docker container
docker run --network bluerange_default -it dimitri/pgloader:latest bash

# in the docker container
# paste script above into a file called: migration.load
# then run
pgloader migration.load
```
