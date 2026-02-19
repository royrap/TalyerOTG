-- Check the actual foreign key constraint name
SELECT
    con.conname AS constraint_name,
    att.attname AS column_name,
    fc.relname AS foreign_table
FROM pg_constraint con
JOIN pg_class rc ON con.conrelid = rc.oid
JOIN pg_attribute att ON att.attrelid = rc.oid AND att.attnum = ANY(con.conkey)
JOIN pg_class fc ON con.confrelid = fc.oid
WHERE rc.relname = 'service_providers'
  AND con.contype = 'f'
  AND att.attname = 'user_id';
