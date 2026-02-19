000_drop_policies_disable_rls.sql

Purpose:
- Drops all row-level security policies in the `public` and `storage` schemas and disables RLS on tables.

Warning:
- This is destructive for access controls. Do NOT run in production unless you understand the implications.
- Keep backups of your database and schema.

How to reverse:
- Re-apply your RLS policy scripts or restore from backup.
- Alternatively, re-enable RLS per-table using `ALTER TABLE schema.table ENABLE ROW LEVEL SECURITY;` and re-create policies with `CREATE POLICY`.

Recommended usage:
- Run in a local or staging environment for debugging if client-side enforcement is preferred temporarily.
- For production, prefer making policies idempotent or using a service role for server-side operations.
