\pset tuples_only
\o kill-output.sql
SELECT 'SELECT pg_terminate_backend(' || pid || ');'
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '1 minute'
AND   usename = 'web';
\o
\i kill-output.sql
\pset tuples_only off

