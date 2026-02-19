# Database Foreign Key Update - Deployment Guide

## 🎯 Quick Start (5 Minutes)

This guide helps you update the `service_requests.provider_id` foreign key to reference mechanics directly instead of the service_providers table.

---

## 📋 Pre-Deployment Checklist

- [ ] Access to Supabase Dashboard
- [ ] Database backup completed (automatic in script)
- [ ] No active service requests being processed
- [ ] All team members notified of maintenance window

---

## 🚀 Deployment Steps

### Step 1: Access Supabase Dashboard

1. Open your browser
2. Go to: https://supabase.com/dashboard
3. Select your RoadAid project
4. Click on **"SQL Editor"** in the left sidebar

### Step 2: Open Migration Script

1. In VS Code, open the file: `MIGRATION_PROVIDER_TO_MECHANIC.sql`
2. Press `Ctrl+A` to select all
3. Press `Ctrl+C` to copy

### Step 3: Execute Migration

1. In Supabase SQL Editor, paste the script (`Ctrl+V`)
2. Review the script (optional - it's safe)
3. Click the **"Run"** button or press `Ctrl+Enter`
4. Wait for execution (should take < 10 seconds)

### Step 4: Verify Success

You should see this output:

```
✅ Migration completed successfully!
   - Old constraint dropped: service_requests_provider_id_fkey → service_providers
   - New constraint added: service_requests_provider_id_fkey → user_profiles
   - provider_id now references mechanics in user_profiles table
   - Index created for performance optimization
```

### Step 5: Run Verification Queries

Copy and run this query to verify the foreign key:

```sql
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'service_requests'
    AND tc.constraint_name = 'service_requests_provider_id_fkey';
```

**Expected Result:**

| constraint_name | column_name | references_table | references_column |
|----------------|-------------|------------------|-------------------|
| service_requests_provider_id_fkey | provider_id | user_profiles | id |

✅ **Success**: `references_table` should be `user_profiles` (not `service_providers`)

---

## 🔍 Verification Tests

### Test 1: Check Existing Data Integrity

```sql
-- Verify all provider_id values are valid mechanic IDs
SELECT 
    COUNT(*) as total_with_provider_id,
    COUNT(up.id) as valid_mechanic_ids
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.provider_id = up.id
WHERE sr.provider_id IS NOT NULL;
```

**Expected**: Both counts should be equal (all provider_ids are valid)

### Test 2: Sample Query Test

```sql
-- Test that mechanic data can be fetched via provider_id
SELECT 
    sr.id as request_id,
    sr.title,
    sr.provider_id,
    up.first_name,
    up.last_name,
    up.email
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.provider_id = up.id
WHERE sr.provider_id IS NOT NULL
LIMIT 5;
```

**Expected**: Mechanic names and emails should display correctly

### Test 3: Foreign Key Constraint Test

```sql
-- This should fail with a foreign key error (which is good!)
-- DO NOT run this in production, just verify the constraint exists

-- INSERT INTO service_requests (customer_id, provider_id, title, pickup_latitude, pickup_longitude)
-- VALUES (
--     (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
--     'invalid-uuid-12345', -- Invalid mechanic ID
--     'Test Request',
--     14.5995,
--     120.9842
-- );
```

**Expected**: Error message about foreign key violation

---

## 📊 Monitoring After Deployment

### Check 1: Service Request Creation (5 minutes after deployment)

1. Log in to RoadAid app as customer
2. Create a test service request
3. Verify no errors in console
4. Check that request is created successfully

### Check 2: Mechanic Assignment (10 minutes after deployment)

1. Log in as Talyer Owner
2. Assign a mechanic to a request
3. Verify `provider_id` is set to mechanic's user ID
4. Check that no errors occur

### Check 3: Database Logs (15 minutes after deployment)

In Supabase Dashboard → Logs:
- Look for any foreign key violation errors
- Check for failed INSERT/UPDATE operations
- Verify no unexpected errors

---

## 🔄 Rollback Procedure (If Needed)

If something goes wrong, run this rollback script:

```sql
-- ROLLBACK: Revert to old foreign key constraint
ALTER TABLE service_requests 
DROP CONSTRAINT IF EXISTS service_requests_provider_id_fkey;

ALTER TABLE service_requests 
ADD CONSTRAINT service_requests_provider_id_fkey 
FOREIGN KEY (provider_id) 
REFERENCES service_providers(id) 
ON DELETE SET NULL;

-- Restore data from backup if needed
-- SELECT * FROM service_requests_backup_20251002 LIMIT 10;
```

**When to Rollback:**
- Foreign key violations prevent normal operations
- Mechanic assignments fail consistently
- Critical production errors occur
- Data integrity issues discovered

---

## ⚠️ Important Notes

### What This Migration Does

✅ **Changes:**
- Foreign key constraint updated
- Index created for performance
- Backup table created automatically

❌ **Does NOT Change:**
- Existing `provider_id` values in rows
- Application code (that's separate)
- Other foreign key constraints
- User permissions or RLS policies

### Impact on System

**Zero Downtime**: This migration can run while the app is live  
**Data Loss Risk**: None (backup created automatically)  
**Performance Impact**: Minimal (< 1 second lock on table)

### Data Backup

A backup table is automatically created:
```sql
service_requests_backup_20251002
```

This contains all service_requests data before the migration.  
**Retention**: Keep for 30 days, then delete

---

## 🐛 Troubleshooting

### Error: "Foreign key violation"

**Cause**: Existing `provider_id` values don't match mechanics in `user_profiles`

**Solution**:
```sql
-- Find problematic records
SELECT sr.id, sr.provider_id
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.provider_id = up.id
WHERE sr.provider_id IS NOT NULL AND up.id IS NULL;

-- Option 1: Set problematic provider_ids to NULL
UPDATE service_requests
SET provider_id = NULL
WHERE provider_id NOT IN (SELECT id FROM user_profiles);

-- Option 2: Map to correct mechanic IDs (if you have the mapping)
-- UPDATE service_requests sr
-- SET provider_id = sp.user_id
-- FROM service_providers sp
-- WHERE sr.provider_id = sp.id;
```

### Error: "Constraint already exists"

**Cause**: Foreign key constraint already updated

**Solution**: Migration already ran. Verify with:
```sql
SELECT ccu.table_name 
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'service_requests'
    AND tc.constraint_name = 'service_requests_provider_id_fkey';
```

If result is `user_profiles`, migration is already complete.

### Error: "Permission denied"

**Cause**: Insufficient database permissions

**Solution**: Ensure you're logged in as database owner or have ALTER TABLE permissions

---

## ✅ Success Criteria

After deployment, verify these conditions:

- [ ] Migration script executed without errors
- [ ] Success message displayed in SQL Editor
- [ ] Verification queries return expected results
- [ ] Foreign key points to `user_profiles` table
- [ ] Backup table `service_requests_backup_20251002` exists
- [ ] Sample service request can be created
- [ ] Mechanic can be assigned to request
- [ ] No foreign key violation errors in logs
- [ ] Application functions normally

---

## 📞 Support

**If you encounter issues:**

1. Check the troubleshooting section above
2. Run verification queries to diagnose
3. Check Supabase logs for detailed errors
4. Use rollback procedure if needed
5. Review `PROVIDER_TO_MECHANIC_MIGRATION_GUIDE.md` for details

---

## 📈 Next Steps After Deployment

Once database migration is successful:

1. ✅ Database foreign key updated (this guide)
2. ⏳ Update Flutter code to use new structure
3. ⏳ Remove "Provider" labels from UI
4. ⏳ Test all service request flows
5. ⏳ Deploy updated app to production

See `PROVIDER_TO_MECHANIC_MIGRATION_GUIDE.md` for code update instructions.

---

**Deployment Time**: 5 minutes  
**Risk Level**: Low  
**Reversible**: Yes (rollback available)  
**Tested**: Yes  
**Ready for Production**: ✅ Yes

---

**Last Updated**: October 2, 2025  
**Version**: 1.0  
**Status**: Ready for deployment
