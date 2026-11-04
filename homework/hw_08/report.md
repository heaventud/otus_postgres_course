## Locks in PostgreSQL
- Relation locks
- Row locks
- Share locks
- Exclusive locks
- Non-relation locks


#### enable logging of lock waits and deadlocks
```postgresql
SET log_lock_waits = on;
SET deadlock_timeout = '200ms';
```


```sql
CREATE TABLE test_lock (id int PRIMARY KEY, val text);
INSERT INTO test_lock VALUES (1, 'init value');
```

#### transaction lock queue in PostgreSQL 

----- session 1 -----
```postgresql
postgres=# 
postgres=# begin;
BEGIN
postgres=*# update test_lock set val = 'next value' where id = 1;
UPDATE 1
postgres=*# commit;
COMMIT
postgres=#
```
---------------------

----- session 2 -----
```postgresql
postgres=# 
postgres=# begin;
BEGIN
postgres=*# update test_lock set val = 'next value 2' where id = 1;
UPDATE 1
postgres=*# commit;
COMMIT
postgres=#
```
---------------------

----- session 3 -----
```postgresql
postgres=# begin;
BEGIN
postgres=*# update test_lock set val = 'next value 3' where id = 1;
UPDATE 1
postgres=*# commit;
COMMIT
postgres=# 
postgres=# select * from test_lock; 
 id |     val      
----+--------------
  1 | next value 3
(1 row)

postgres=#
```
---------------------


```postgresql
postgres=# show deadlock_timeout
postgres-# ;
 deadlock_timeout 
------------------
 1s
(1 row)

postgres=# show log_lock_waits;
 log_lock_waits 
----------------
 on
(1 row)

postgres=# SELECT 
    l.pid AS process_id,
    a.usename AS user_name,
    a.query AS current_statement,
    l.locktype AS lock_type,
    l.mode AS lock_mode,
    l.granted,
    c.relname AS table_name
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
LEFT JOIN pg_class c ON l.relation = c.oid
WHERE a.pid <> pg_backend_pid();
 process_id | user_name |                    current_statement                    |   lock_type   |    lock_mode     | granted |   table_name   | 
------------+-----------+---------------------------------------------------------+---------------+------------------+---------+----------------|
       1230 | postgres  | update test_lock set val = 'next value 3' where id = 1; | relation      | RowExclusiveLock | t       | test_lock_pkey | транзакция получила granted для защиты от изменения структуры таблицы
       1230 | postgres  | update test_lock set val = 'next value 3' where id = 1; | relation      | RowExclusiveLock | t       | test_lock.     | транзакция получила granted на изменение таблицы
       1230 | postgres  | update test_lock set val = 'next value 3' where id = 1; | virtualxid    | ExclusiveLock    | t       |                | транзакция повесила lock на виртуальный номер
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | relation      | RowExclusiveLock | t       | test_lock_pkey | транзакция получила granted для защиты от изменения структуры таблицы
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | relation      | RowExclusiveLock | t       | test_lock      | транзакция получила granted на изменение таблицы
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | virtualxid    | ExclusiveLock    | t       |                | транзакция повесила lock на виртуальный номер
       1181 | postgres  | update test_lock set val = 'next value' where id = 1;   | relation      | RowExclusiveLock | t       | test_lock_pkey.| транзакция получила granted для защиты от изменения структуры таблицы
       1181 | postgres  | update test_lock set val = 'next value' where id = 1;   | relation      | RowExclusiveLock | t       | test_lock      | транзакция получила granted на изменение таблицы
       1181 | postgres  | update test_lock set val = 'next value' where id = 1;   | virtualxid    | ExclusiveLock    | t       |                | транзакция повесила lock на виртуальный номер
       1230 | postgres  | update test_lock set val = 'next value 3' where id = 1; | tuple         | ExclusiveLock    | f       | test_lock      | транзакция встала в очередь на изменение строки
       1181 | postgres  | update test_lock set val = 'next value' where id = 1;   | transactionid | ExclusiveLock    | t       |                | транзакция повесила lock на себя для организации очереди
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | tuple         | ExclusiveLock    | t       | test_lock      | транзакция поличила lock чтобы встать в очередь
       1230 | postgres  | update test_lock set val = 'next value 3' where id = 1; | transactionid | ExclusiveLock    | t       |                | транзакция повесила lock на себя для организации очереди
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | transactionid | ExclusiveLock    | t       |                | транзакция повесила lock на себя для организации очереди
       1205 | postgres  | update test_lock set val = 'next value 2' where id = 1; | transactionid | ShareLock        | f       |                | транзакция не получила lock и ждет выполнения 1ой транзакции
(15 rows)

postgres=# 
```


Итог:

1. 1181 — выполняет операцию.
2. 1205 — Вторая в очереди (заняла tuple, ждет транзакцию 1181).
3. 1230 — Третья в очереди (ждет tuple, который занят процессом 1205).


#### Example of deadlocking

----- session 1 -----

```postgresql
postgres=# begin;
BEGIN
postgres=*# update test_lock set val='line 1' where id=1;
UPDATE 1
postgres=*# update test_lock set val='line 1-3' where id=3;
UPDATE 1
postgres=*# commit;
COMMIT
postgres=# 
```
---------------------


----- session 2 -----

```postgresql
postgres=# begin;
BEGIN
postgres=*# update test_lock set val='line 2' where id=2;
UPDATE 1
postgres=*# update test_lock set val='line 2-1' where id=1;
UPDATE 1
postgres=*# commit;
COMMIT
postgres=# 
```

---------------------


----- session 3 -----
```postgresql
postgres=# begin;
BEGIN
postgres=*# update test_lock set val='line 3' where id=3;
UPDATE 1
postgres=*# update test_lock set val='line 3-2' where id=2;
ERROR:  deadlock detected
DETAIL:  Process 1230 waits for ShareLock on transaction 515900; blocked by process 1205.
Process 1205 waits for ShareLock on transaction 515899; blocked by process 1181.
Process 1181 waits for ShareLock on transaction 515901; blocked by process 1230.
HINT:  See server log for query details.
CONTEXT:  while updating tuple (0,18) in relation "test_lock"
postgres=!# 
```
---------------------


------- check logs -----

```log
root@ef7beae6d7f1:/# psql -U postgres
psql (16.15 (Debian 16.15-1.pgdg13+2))
Type "help" for help.

postgres=# SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.query AS blocked_statement,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
 blocked_pid |                blocked_statement                | blocking_pid |               blocking_statement                
-------------+-------------------------------------------------+--------------+-------------------------------------------------
        1205 | update test_lock set val='line 2-1' where id=1; |         1181 | update test_lock set val='line 1-3' where id=3;
(1 row)

postgres=# SELECT 
    l.pid AS process_id,
    a.usename AS user_name,
    a.query AS current_statement,
    l.locktype AS lock_type,
    l.mode AS lock_mode,
    l.granted,
    c.relname AS table_name
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
LEFT JOIN pg_class c ON l.relation = c.oid
WHERE a.pid <> pg_backend_pid();
 process_id | user_name |                current_statement                |   lock_type   |    lock_mode     | granted |   table_name   
------------+-----------+-------------------------------------------------+---------------+------------------+---------+----------------
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | relation      | RowExclusiveLock | t       | test_lock_pkey
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | relation      | RowExclusiveLock | t       | test_lock
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | virtualxid    | ExclusiveLock    | t       | 
       1181 | postgres  | update test_lock set val='line 1-3' where id=3; | relation      | RowExclusiveLock | t       | test_lock_pkey
       1181 | postgres  | update test_lock set val='line 1-3' where id=3; | relation      | RowExclusiveLock | t       | test_lock
       1181 | postgres  | update test_lock set val='line 1-3' where id=3; | virtualxid    | ExclusiveLock    | t       | 
       1181 | postgres  | update test_lock set val='line 1-3' where id=3; | transactionid | ExclusiveLock    | t       | 
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | transactionid | ExclusiveLock    | t       | 
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | tuple         | ExclusiveLock    | t       | test_lock
       1205 | postgres  | update test_lock set val='line 2-1' where id=1; | transactionid | ShareLock        | f       | 
(10 rows)

postgres=# 
postgres=# 
\q
root@ef7beae6d7f1:/# cat /var/lib/postgresql/data/log/postgresql-*.log
2026-11-02 12:37:26.448 UTC [1] LOG:  starting PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on aarch64-unknown-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
2026-11-02 12:37:26.448 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-11-02 12:37:26.448 UTC [1] LOG:  listening on IPv6 address "::", port 5432
2026-11-02 12:37:26.448 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-11-02 12:37:26.449 UTC [30] LOG:  database system was shut down at 2026-11-02 12:27:45 UTC
2026-11-02 12:37:26.452 UTC [1] LOG:  database system is ready to accept connections
2026-11-02 12:38:08.004 UTC [110] FATAL:  role "root" does not exist
2026-11-02 12:39:26.761 UTC [1] LOG:  received SIGHUP, reloading configuration files
2026-11-02 12:42:26.846 UTC [28] LOG:  checkpoint starting: time
2026-11-02 12:42:30.047 UTC [28] LOG:  checkpoint complete: wrote 34 buffers (0.2%); 0 WAL file(s) added, 0 removed, 0 recycled; write=3.201 s, sync=0.001 s, total=3.202 s; sync files=0, longest=0.000 s, average=0.000 s; distance=148 kB, estimate=148 kB; lsn=0/1F2B4290, redo lsn=0/1F2B4208
2026-11-02 12:54:25.780 UTC [1726] FATAL:  role "root" does not exist
2026-11-02 12:54:39.304 UTC [1746] FATAL:  role "root" does not exist
2026-11-02 12:56:05.340 UTC [125] ERROR:  syntax error at or near "WHERE" at character 29
2026-11-02 12:56:05.340 UTC [125] STATEMENT:  UPDATE test_lock SET val =  WHERE id = 1;
2026-11-02 12:56:27.467 UTC [125] ERROR:  current transaction is aborted, commands ignored until end of transaction block
2026-11-02 12:56:27.467 UTC [125] STATEMENT:  select pg_backend_trabsaaction();
2026-11-02 12:56:42.384 UTC [125] ERROR:  current transaction is aborted, commands ignored until end of transaction block
2026-11-02 12:56:42.384 UTC [125] STATEMENT:  select pg_backend;
2026-11-02 12:57:26.206 UTC [28] LOG:  checkpoint starting: time
2026-11-02 12:57:26.622 UTC [28] LOG:  checkpoint complete: wrote 5 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.415 s, sync=0.001 s, total=0.416 s; sync files=0, longest=0.000 s, average=0.000 s; distance=2 kB, estimate=133 kB; lsn=0/1F2B4AA8, redo lsn=0/1F2B4A70
2026-11-02 12:57:51.509 UTC [125] ERROR:  current transaction is aborted, commands ignored until end of transaction block
2026-11-02 12:57:51.509 UTC [125] STATEMENT:  select pg_backend_pid();
2026-11-02 12:57:55.289 UTC [125] ERROR:  current transaction is aborted, commands ignored until end of transaction block
2026-11-02 12:57:55.289 UTC [125] STATEMENT:  select pg_backend_pid;
2026-11-02 12:59:55.380 UTC [1764] LOG:  process 1764 still waiting for ShareLock on transaction 514489 after 1002.279 ms
2026-11-02 12:59:55.380 UTC [1764] DETAIL:  Process holding the lock: 2109. Wait queue: 1764.
2026-11-02 12:59:55.380 UTC [1764] CONTEXT:  while updating tuple (0,1) in relation "test_lock"
2026-11-02 12:59:55.380 UTC [1764] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 12:59:57.477 UTC [1796] LOG:  process 1796 still waiting for ExclusiveLock on tuple (0,1) of relation 16429 of database 5 after 1004.315 ms
2026-11-02 12:59:57.477 UTC [1796] DETAIL:  Process holding the lock: 1764. Wait queue: 1796.
2026-11-02 12:59:57.477 UTC [1796] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 13:02:26.710 UTC [28] LOG:  checkpoint starting: time
2026-11-02 13:02:27.019 UTC [28] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.309 s, sync=0.001 s, total=0.310 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=120 kB; lsn=0/1F2B4C88, redo lsn=0/1F2B4C48
2026-11-02 13:28:00.783 UTC [1764] LOG:  process 1764 acquired ShareLock on transaction 514489 after 1686405.341 ms
2026-11-02 13:28:00.783 UTC [1764] CONTEXT:  while updating tuple (0,1) in relation "test_lock"
2026-11-02 13:28:00.783 UTC [1764] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 13:28:00.783 UTC [1796] LOG:  process 1796 acquired ExclusiveLock on tuple (0,1) of relation 16429 of database 5 after 1684310.705 ms
2026-11-02 13:28:00.783 UTC [1796] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 13:28:01.788 UTC [1796] LOG:  process 1796 still waiting for ShareLock on transaction 514490 after 1004.641 ms
2026-11-02 13:28:01.788 UTC [1796] DETAIL:  Process holding the lock: 1764. Wait queue: 1796.
2026-11-02 13:28:01.788 UTC [1796] CONTEXT:  while rechecking updated tuple (0,2) in relation "test_lock"
2026-11-02 13:28:01.788 UTC [1796] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 13:28:25.251 UTC [1796] LOG:  process 1796 acquired ShareLock on transaction 514490 after 24468.259 ms
2026-11-02 13:28:25.251 UTC [1796] CONTEXT:  while rechecking updated tuple (0,2) in relation "test_lock"
2026-11-02 13:28:25.251 UTC [1796] STATEMENT:  UPDATE test_lock SET val = pg_backend_pid() where id = 1;
2026-11-02 13:32:26.443 UTC [28] LOG:  checkpoint starting: time
2026-11-02 13:32:26.550 UTC [28] LOG:  checkpoint complete: wrote 2 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.106 s, sync=0.001 s, total=0.107 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=108 kB; lsn=0/1F2B5018, redo lsn=0/1F2B4FE0
2026-11-02 14:42:27.912 UTC [28] LOG:  checkpoint starting: time
2026-11-02 14:42:28.115 UTC [28] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.203 s, sync=0.001 s, total=0.204 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1 kB, estimate=97 kB; lsn=0/1F2B5450, redo lsn=0/1F2B5418
2026-11-02 14:43:55.028 UTC [2109] WARNING:  there is no transaction in progress
2026-11-02 14:47:27.151 UTC [28] LOG:  checkpoint starting: time
2026-11-02 14:47:27.256 UTC [28] LOG:  checkpoint complete: wrote 2 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.106 s, sync=0.001 s, total=0.106 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1 kB, estimate=87 kB; lsn=0/1F2B5B48, redo lsn=0/1F2B5B10
2026-11-02 14:52:27.316 UTC [28] LOG:  checkpoint starting: time
2026-11-02 14:52:27.421 UTC [28] LOG:  checkpoint complete: wrote 2 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.106 s, sync=0.001 s, total=0.106 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1 kB, estimate=79 kB; lsn=0/1F2B5FF0, redo lsn=0/1F2B5FB8
2026-11-03 14:34:19.444 UTC [72634] FATAL:  password authentication failed for user "postgres"
2026-11-03 14:34:19.444 UTC [72634] DETAIL:  Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 128: "host all all all scram-sha-256"
2026-11-03 14:36:35.099 UTC [28] LOG:  checkpoint starting: time
2026-11-03 14:39:03.243 UTC [28] LOG:  checkpoint complete: wrote 1405 buffers (8.6%); 0 WAL file(s) added, 0 removed, 0 recycled; write=148.144 s, sync=0.001 s, total=148.145 s; sync files=0, longest=0.000 s, average=0.000 s; distance=10074 kB, estimate=10074 kB; lsn=0/1FCAA4B0, redo lsn=0/1FC8CA58
2026-11-03 15:11:35.560 UTC [28] LOG:  checkpoint starting: time
2026-11-03 15:11:45.808 UTC [28] LOG:  checkpoint complete: wrote 101 buffers (0.6%); 0 WAL file(s) added, 0 removed, 0 recycled; write=10.246 s, sync=0.001 s, total=10.249 s; sync files=0, longest=0.000 s, average=0.000 s; distance=418 kB, estimate=9109 kB; lsn=0/1FCF5458, redo lsn=0/1FCF5420
2026-11-03 16:06:36.802 UTC [28] LOG:  checkpoint starting: time
2026-11-03 16:06:51.454 UTC [28] LOG:  checkpoint complete: wrote 144 buffers (0.9%); 0 WAL file(s) added, 0 removed, 0 recycled; write=14.652 s, sync=0.001 s, total=14.653 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1008 kB, estimate=8298 kB; lsn=0/1FDF14B0, redo lsn=0/1FDF1478
2026-11-04 09:22:11.949 UTC [28] LOG:  checkpoint starting: time
2026-11-04 09:22:11.951 UTC [28] LOG:  checkpoint complete: wrote 1 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.002 s, sync=0.001 s, total=0.003 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=7469 kB; lsn=0/1FDF15F8, redo lsn=0/1FDF15C0
2026-11-04 09:49:48.151 UTC [2109] ERROR:  syntax error at or near "(" at character 29
2026-11-04 09:49:48.151 UTC [2109] STATEMENT:  update test_lock set values ('1') where id =1;
2026-11-04 09:50:16.739 UTC [2109] WARNING:  there is no transaction in progress
2026-11-04 09:51:33.868 UTC [1] LOG:  received fast shutdown request
2026-11-04 09:51:33.868 UTC [1] LOG:  aborting any active transactions
2026-11-04 09:51:33.870 UTC [1] LOG:  background worker "logical replication launcher" (PID 33) exited with exit code 1
2026-11-04 09:51:33.870 UTC [28] LOG:  shutting down
2026-11-04 09:51:33.870 UTC [28] LOG:  checkpoint starting: shutdown immediate
2026-11-04 09:51:33.871 UTC [28] LOG:  checkpoint complete: wrote 2 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.001 s, sync=0.001 s, total=0.001 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1 kB, estimate=6722 kB; lsn=0/1FDF1B60, redo lsn=0/1FDF1B60
2026-11-04 09:51:33.877 UTC [1] LOG:  database system is shut down
2026-11-04 09:51:34.038 UTC [1] LOG:  starting PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on aarch64-unknown-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
2026-11-04 09:51:34.038 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2026-11-04 09:51:34.038 UTC [1] LOG:  listening on IPv6 address "::", port 5432
2026-11-04 09:51:34.038 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-11-04 09:51:34.038 UTC [30] LOG:  database system was shut down at 2026-11-04 09:51:33 UTC
2026-11-04 09:51:34.040 UTC [1] LOG:  database system is ready to accept connections
2026-11-04 09:56:34.143 UTC [28] LOG:  checkpoint starting: time
2026-11-04 09:56:34.347 UTC [28] LOG:  checkpoint complete: wrote 5 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.203 s, sync=0.001 s, total=0.204 s; sync files=0, longest=0.000 s, average=0.000 s; distance=7 kB, estimate=7 kB; lsn=0/1FDF3A10, redo lsn=0/1FDF39D8
2026-11-04 10:03:56.361 UTC [1181] ERROR:  syntax error at or near "upadte" at character 1
2026-11-04 10:03:56.361 UTC [1181] STATEMENT:  upadte test_lock set val='line 1' where id=1;
2026-11-04 10:04:10.661 UTC [1181] ERROR:  current transaction is aborted, commands ignored until end of transaction block
2026-11-04 10:04:10.661 UTC [1181] STATEMENT:  update test_lock set val='line 1' where id=1;
2026-11-04 10:05:18.276 UTC [1181] LOG:  process 1181 still waiting for ShareLock on transaction 515901 after 1005.244 ms
2026-11-04 10:05:18.276 UTC [1181] DETAIL:  Process holding the lock: 1230. Wait queue: 1181.
2026-11-04 10:05:18.276 UTC [1181] CONTEXT:  while updating tuple (0,19) in relation "test_lock"
2026-11-04 10:05:18.276 UTC [1181] STATEMENT:  update test_lock set val='line 1-3' where id=3;
2026-11-04 10:05:29.990 UTC [1205] LOG:  process 1205 still waiting for ShareLock on transaction 515899 after 1003.895 ms
2026-11-04 10:05:29.990 UTC [1205] DETAIL:  Process holding the lock: 1181. Wait queue: 1205.
2026-11-04 10:05:29.990 UTC [1205] CONTEXT:  while updating tuple (0,17) in relation "test_lock"
2026-11-04 10:05:29.990 UTC [1205] STATEMENT:  update test_lock set val='line 2-1' where id=1;
2026-11-04 10:05:46.398 UTC [1230] LOG:  process 1230 detected deadlock while waiting for ShareLock on transaction 515900 after 1001.993 ms
2026-11-04 10:05:46.398 UTC [1230] DETAIL:  Process holding the lock: 1205. Wait queue: .
2026-11-04 10:05:46.398 UTC [1230] CONTEXT:  while updating tuple (0,18) in relation "test_lock"
2026-11-04 10:05:46.398 UTC [1230] STATEMENT:  update test_lock set val='line 3-2' where id=2;
2026-11-04 10:05:46.398 UTC [1230] ERROR:  deadlock detected
2026-11-04 10:05:46.398 UTC [1230] DETAIL:  Process 1230 waits for ShareLock on transaction 515900; blocked by process 1205.
        Process 1205 waits for ShareLock on transaction 515899; blocked by process 1181.
        Process 1181 waits for ShareLock on transaction 515901; blocked by process 1230.
        Process 1230: update test_lock set val='line 3-2' where id=2;
        Process 1205: update test_lock set val='line 2-1' where id=1;
        Process 1181: update test_lock set val='line 1-3' where id=3;
2026-11-04 10:05:46.398 UTC [1230] HINT:  See server log for query details.
2026-11-04 10:05:46.398 UTC [1230] CONTEXT:  while updating tuple (0,18) in relation "test_lock"
2026-11-04 10:05:46.398 UTC [1230] STATEMENT:  update test_lock set val='line 3-2' where id=2;
2026-11-04 10:05:46.398 UTC [1181] LOG:  process 1181 acquired ShareLock on transaction 515901 after 29126.921 ms
2026-11-04 10:05:46.398 UTC [1181] CONTEXT:  while updating tuple (0,19) in relation "test_lock"
2026-11-04 10:05:46.398 UTC [1181] STATEMENT:  update test_lock set val='line 1-3' where id=3;
2026-11-04 10:06:34.507 UTC [28] LOG:  checkpoint starting: time
2026-11-04 10:06:34.613 UTC [28] LOG:  checkpoint complete: wrote 2 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.106 s, sync=0.001 s, total=0.107 s; sync files=0, longest=0.000 s, average=0.000 s; distance=1 kB, estimate=7 kB; lsn=0/1FDF40A0, redo lsn=0/1FDF4060
root@ef7beae6d7f1:/# 
root@ef7beae6d7f1:/# 
```

Вопрос: Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?

Ответ:
https://habr.com/ru/companies/postgrespro/articles/465263/

такое может произойти, если 1ая транзакция начнет выполнять UPDATE "сначала" таблицы, а 2ая 
(например, из-за особенностей работы дискового кэша или параллельного инкрементального сканирования) с конца таблицы, тогда 
поскольку полный UPDATE таблицы в реальности происходит по-строчно, то и блокировка таблицы происходит по-строчно, и может случится 
что 1ая транзакция не успев обновить таблицу заблокировав и обновив предыдущую строку перейдет к следующей, которую в свою
очередь заблокировала 2ая транзакция. И тоже самое делает другая.


