--------- 1st session ---------
BEGIN ISOLATION LEVEL READ COMMITTED;
    INSERT INTO orders (amount) VALUES (11.2);
COMMIT;

--------- 2nd session ---------
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT count(*), sum(amount)
FROM orders
WHERE created_at >= now() - interval '10 min';
COMMIT;


--------- 1st session ---------
BEGIN ISOLATION LEVEL REPEATABLE READ;
    INSERT INTO orders (amount) VALUES (22.1);
COMMIT;

--------- 2nd session ---------
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT count(*), sum(amount)
FROM orders
WHERE created_at >= now() - interval '10 min';
COMMIT;
