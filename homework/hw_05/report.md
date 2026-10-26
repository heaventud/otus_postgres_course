## Transaction Isolation Levels in Postgres
  - Read Uncommitted
  - Read Committed
  - Repeatable Read
  - Serializable

#### Prepare data in test table

```sql
CREATE TABLE IF NOT EXISTS orders (
    id serial PRIMARY KEY,
    amount numeric(10,2) NOT NULL,
    created_at timestamptz DEFAULT now()
);
INSERT INTO orders (amount) VALUES 
    (100.88), (86.22), (45.21)
;
SELECT count(*) FROM orders;
```

---------------
READ COMMITTED
---------------

--------- 1st session ---------

```bash
postgres=# CREATE TABLE IF NOT EXISTS orders (
    id serial PRIMARY KEY,
    amount numeric(10,2) NOT NULL,
    created_at timestamptz DEFAULT now()
);
CREATE TABLE
postgres=# 
postgres=# INSERT INTO orders (amount) VALUES 
    (100.88), (86.22), (45.21)
;
INSERT 0 3
postgres=# 
postgres=# \set autocommit off;
postgres=# BEGIN ISOLATION LEVEL READ COMMITTED;
BEGIN
postgres=*# INSERT INTO orders (amount) VALUES (11.2);
INSERT 0 1
postgres=*# select count(*) from orders;
 count 
-------
     4
(1 row)

postgres=*# commit;
COMMIT
postgres=# 
```

--------- 2nd session ---------

```bash
postgres=# \set autocommit off;
postgres=# BEGIN ISOLATION LEVEL READ COMMITTED;
BEGIN
postgres=*# select count(*) from orders; 
 count 
-------
     3
(1 row)

postgres=*# select count(*) from orders; 
 count 
-------
     3
(1 row)

postgres=*# select count(*) from orders; 
 count 
-------
     3
(1 row)

postgres=*# select count(*) from orders; 
 count 
-------
     4
(1 row)

postgres=*# commit
postgres-*# ;
COMMIT
postgres=# 
```

Выыод:
в PostgreSql на уровне изоляции READ COMMITED, 'грязное чтение' т.е. чтение незафиксированных данных исключанется, но 
чтение зафиксированных в другой транзакции данных (фантомное чтение) разрешено. 

----------------
REPEATABLE READ
----------------

--------- 1st session ---------

```bash
postgres=# 
postgres=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
postgres=*# INSERT INTO orders (amount) VALUES (22.1);
INSERT 0 1
postgres=*# select count(*) from orders;
 count 
-------
     5
(1 row)

postgres=*# SELECT count(*), sum(amount)
FROM orders
WHERE created_at >= now() - interval '10 min';
 count |  sum   
-------+--------
     5 | 265.61
(1 row)

postgres=*# commit;
COMMIT
postgres=# 
```

--------- 2nd session ---------

```bash
postgres=# 
postgres=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
postgres=*# SELECT count(*), sum(amount)
FROM orders
WHERE created_at >= now() - interval '10 min';
 count |  sum   
-------+--------
     4 | 243.51
(1 row)

postgres=*# SELECT count(*), sum(amount)
FROM orders
WHERE created_at >= now() - interval '10 min';
 count |  sum   
-------+--------
     4 | 243.51
(1 row)

postgres=*# commit; 
COMMIT
postgres=# 
```

Вывод: 
В PostgreSql на уровне изоляции REPEATABLE READ "фантомное чтение" исключается реализацией:
при повторном чтении данных, если они не были изменены внутри самой транзакции, то они будут иметь те же значения, 
что и при первом чтении. 
Для составления например бухгалтерского отчета в идеале больше подходит уровень REPEATABLE READ, 
поскольку в процессе сборки отчета гарантируется, что данные не разойдутся.
