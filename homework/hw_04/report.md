## PostgreSQL configuration and benchmark

-- Initialize test db and tables

```bash
$ pgbench -i --scale 10 -h localhost -U test_user -d my_test_db -q
```

-- Run benchmark test

```bash
$ pgbench -c 10 -j 4 -T 60 -h localhost -U test_user -d my_test_db
```

-- Make optimizations in postgres configuration

```pgsql
\x;
SELECT * FROM pg_settings WHERE name='synchronous_commit' OR name='fsync';
;
SHOW synchronous_commit;
SHOW fsync;
ALTER SYSTEM SET synchronous_commit = 'off';
ALTER SYSTEM SET fsync = 'off';
SELECT pg_reload_conf();
SHOW synchronous_commit;
```

-- Run benchmark test again to check optimizations

```bash
$ pgbench -c 10 -j 4 -T 60 -h localhost -U test_user -d my_test_db
```

#### Demo
![demo](task_4.gif)


#### Conclusions

```txt
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 10
query mode: simple
number of clients: 10
number of threads: 4
duration: 60 s
number of transactions actually processed: 164019
latency average = 3.656 ms
initial connection time = 36.671 ms
tps = 2734.970353 (without initial connection time)  
```

```text
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 10
query mode: simple
number of clients: 10
number of threads: 4
duration: 60 s
number of transactions actually processed: 184642
latency average = 3.248 ms
initial connection time = 32.694 ms
tps = 3078.573981 (without initial connection time)    
```


