\pset tuples_only
\o cancel-output.sql
SELECT 'SELECT pg_cancel_backend(' || pid || ');'
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minute'
AND   usename = 'web';
\o
\i cancel-output.sql
\pset tuples_only off
