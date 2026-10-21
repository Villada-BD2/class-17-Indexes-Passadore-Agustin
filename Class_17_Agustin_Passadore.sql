USE sakila;

SET profiling = 1;

-- ------------------- 1 ------------------------------

-- SHOW INDEX FROM address;


SELECT * FROM address
WHERE postal_code IN ('67055', '25007', '21954');
-- 0.003

SELECT * FROM address
WHERE postal_code NOT IN ('67055', '25007', '21954');
-- 0.017s

SELECT a.address, a.postal_code, c.city, co.country
FROM address a
INNER JOIN city c ON a.city_id = c.city_id
INNER JOIN country co ON c.country_id = co.country_id
WHERE a.postal_code IN ('67055', '25007', '21954');
-- 0.003s

-- --------------------
CREATE INDEX index_for_postal_code ON address(postal_code);
-- --------------------

SELECT * FROM address
WHERE postal_code IN ('67055', '25007', '21954');
-- 0.002s

SELECT * FROM address
WHERE postal_code NOT IN ('67055', '25007', '21954');
-- 0.006s

SELECT a.address, a.postal_code, c.city, co.country
FROM address a
INNER JOIN city c ON a.city_id = c.city_id
INNER JOIN country co ON c.country_id = co.country_id
WHERE a.postal_code IN ('67055', '25007', '21954');
-- 0.002s


-- Results:
--                       Before index    After index
-- Query 1 (IN)             0.003s          0.002s
-- Query 2 (NOT IN)         0.017s          0.006s
-- Query 3 (IN + joins)     0.003s          0.002s

-- Before the index, MySQL has no way to find the rows with a given
-- postal_code other than reading every row of the address table and checking
-- the condition on each one, what it is a full table scan. The cost grows with the
-- number of rows in the table.
-- After "CREATE INDEX" index_postal_code, MySQL keeps the postal_code values in a
-- defined structure. For the IN queries it can look up each postal
-- code directly

-- DROP INDEX index_postal_code ON address;

-- ------------------- 2 ------------------------------
SHOW INDEX FROM actor;

-- ---------- BEFORE creating an index on first_name ----------

-- w index
SELECT * FROM actor WHERE last_name = 'WAHLBERG';

-- no index
SELECT * FROM actor WHERE first_name = 'NICK';

-- --------------------
CREATE INDEX index_actor_first_name ON actor(first_name);

-- --------------------

SELECT * FROM actor WHERE last_name = 'WAHLBERG';

SELECT * FROM actor WHERE first_name = 'NICK';

SHOW PROFILES;
SET profiling = 0;

-- Cleanup (optional)
-- DROP INDEX idx_actor_first_name ON actor;

/*
RESULTS (execution time in seconds)
                              Before index    After index
Search by last_name           0.003s          0.001s
Search by first_name           _              0.005s


MySQL can only use an index on the column that appears in the WHERE clause.
The last_name column already had an index (idx_actor_last_name), so searching
by last name goes straight to the matching entries in the index. The first_name
column had no index, so MySQL had to read every row of the actor table and
check the condition on each one.

The diference is samll since actor only has ~200 rows
*/

-- ------------------- 3 ------------------------------

SHOW INDEX FROM film_text;

-- ----------
SELECT film_id, title
FROM film
WHERE description LIKE '%crocodile%';

-- ----------
SELECT film_id, title
FROM film_text
WHERE MATCH(title, description) AGAINST('crocodile');

-- ----------
SELECT film_id, title,
       MATCH(title, description) AGAINST('crocodile') AS score
FROM film_text
WHERE MATCH(title, description) AGAINST('crocodile');

-- ----------
SELECT film_id, title
FROM film
WHERE description LIKE '%crocodile%'
  AND description NOT LIKE '%shark%';

-- ----------
SELECT film_id, title
FROM film_text
WHERE MATCH(title, description) AGAINST('+crocodile -shark' IN BOOLEAN MODE);

SHOW PROFILES;
SET profiling = 0;

/*
EXERCISE 3: RESULTS (execution time in seconds)
Query 1 (LIKE, one word)                  0.004s
Query 2 (MATCH, one word)                 0.001s
Query 3 (MATCH with score)                0.001s
Query 4 (LIKE, crocodile but not shark)   0.004s
Query 5 (MATCH boolean mode)              0.001s

EXPLANATION
LIKE '%crocodile%' has to read the description of every film to look for the
text inside it, so it checks all the rows. MATCH ... AGAINST uses the FULLTEXT
index, which works like a list of words, so MySQL finds the word directly
instead of reading everything. MATCH also sorts the results by relevance and
lets us write conditions like "this word but not that one" easily (boolean
mode). One difference: LIKE finds text anywhere, even inside longer words, while
MATCH only finds whole words, so it can return fewer rows. The times are close
because the table has only 1000 rows, but with a much bigger table MATCH would
be a lot faster.
*/

SET profiling = 0;