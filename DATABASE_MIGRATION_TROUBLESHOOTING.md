# 🔧 DATABASE MIGRATION TROUBLESHOOTING GUIDE

## Common Error: "column 'user_id' does not exist"

### Problem Description
The error `ERROR: 42703: column "user_id" does not exist` occurs when the SQL script references columns that don't exist in your current database schema.

### Root Cause
The original script assumed certain column names that may differ in your existing database structure.

## 🎯 SOLUTION: Use the Safe Migration Script

Instead of the original `COMPLETE_PROFILE_MANAGEMENT_SCHEMA.sql`, use the **`SAFE_PROFILE_MANAGEMENT_MIGRATION.sql`** script which:

- ✅ **Checks for existing tables and columns before creating**
- ✅ **Uses safe column references**
- ✅ **Handles missing dependencies gracefully**
- ✅ **Provides detailed feedback during execution**

## 📋 Pre-Migration Checklist

### 1. Check Your Current Schema
Before running any migration, check your existing tables:

```sql
-- Check if user_profiles table exists and its structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
ORDER BY ordinal_position;

-- Check if service_providers table exists
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'service_providers' 
ORDER BY ordinal_position;

-- Check existing tables in public schema
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

### 2. Backup Your Database
Always backup before migration:

```sql
-- Create a backup (adjust for your environment)
pg_dump your_database_name > backup_before_migration.sql
```

## 🚀 Step-by-Step Migration Process

### Step 1: Run the Safe Migration Script
Execute `SAFE_PROFILE_MANAGEMENT_MIGRATION.sql` in your Supabase SQL editor:

```sql
-- This script handles all safety checks automatically
-- Just copy and paste the entire content
```

### Step 2: Verify the Migration
After running the migration, verify the new tables exist:

```sql
-- Check new tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'email_notifications',
    'temporary_passwords', 
    'profile_updates',
    'app_downloads',
    'app_settings'
)
ORDER BY table_name;

-- Check new columns were added to user_profiles
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN (
    'profile_image_url',
    'first_login_completed',
    'password_change_required'
);
```

### Step 3: Test the Email Templates
Verify email templates were inserted:

```sql
-- Check email templates
SELECT key, description 
FROM public.app_settings 
WHERE category = 'email_templates'
ORDER BY key;
```

## 🔍 Common Issues and Solutions

### Issue 1: "relation 'storage.buckets' does not exist"
**Solution**: Storage is not configured in your Supabase project.
```sql
-- Skip storage-related commands or configure storage first
-- The migration script handles this gracefully
```

### Issue 2: "function auth.uid() does not exist"
**Solution**: RLS policies depend on Supabase auth functions.
```sql
-- Make sure you're running this in Supabase, not a regular PostgreSQL instance
-- The script includes safety checks for this
```

### Issue 3: "column references are ambiguous"
**Solution**: Use fully qualified column names.
```sql
-- Instead of: user_id
-- Use: table_name.user_id
-- The safe migration script handles this
```

### Issue 4: "constraint already exists"
**Solution**: Use IF NOT EXISTS or DROP IF EXISTS.
```sql
-- The safe migration script uses these patterns:
DROP POLICY IF EXISTS "policy_name" ON table_name;
CREATE POLICY "policy_name" ON table_name ...
```

## 🔧 Manual Fixes for Specific Errors

### Fix 1: Add Missing Columns Manually
If columns are missing, add them individually:

```sql
-- Add profile_image_url if missing
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

-- Add first_login_completed if missing  
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS first_login_completed BOOLEAN DEFAULT FALSE;

-- Add password_change_required if missing
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS password_change_required BOOLEAN DEFAULT FALSE;
```

### Fix 2: Create Email Notifications Table Manually
```sql
CREATE TABLE IF NOT EXISTS public.email_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_user_id UUID,
    sender_user_id UUID,
    email_type TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    template_data JSONB,
    sent_at TIMESTAMPTZ,
    delivery_status TEXT DEFAULT 'pending',
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Fix 3: Create App Settings Table Manually
```sql
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'general',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 📊 Verification Queries

### Check Migration Success
```sql
-- Verify all new features are available
SELECT 
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_name = 'user_profiles' 
     AND column_name = 'profile_image_url') as profile_image_col,
    (SELECT COUNT(*) FROM information_schema.tables 
     WHERE table_name = 'email_notifications') as email_notifications_table,
    (SELECT COUNT(*) FROM information_schema.tables 
     WHERE table_name = 'app_settings') as app_settings_table,
    (SELECT COUNT(*) FROM public.app_settings 
     WHERE category = 'email_templates') as email_templates_count;
```

### Test Email Template Functionality
```sql
-- Get a sample email template
SELECT value 
FROM public.app_settings 
WHERE key = 'email_change_welcome_template';
```

## 🎯 Success Indicators

After successful migration, you should see:

- ✅ **3 new columns** in `user_profiles` table
- ✅ **5 new tables** created (`email_notifications`, `temporary_passwords`, `profile_updates`, `app_downloads`, `app_settings`)
- ✅ **4 email templates** in `app_settings` table
- ✅ **No errors** during script execution
- ✅ **Proper indexes** created for performance
- ✅ **RLS policies** applied for security

## 🆘 Emergency Rollback

If something goes wrong, you can rollback:

```sql
-- Remove new columns (DANGER: This will lose data!)
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS profile_image_url;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS first_login_completed;
ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS password_change_required;

-- Drop new tables (DANGER: This will lose data!)
DROP TABLE IF EXISTS public.app_downloads;
DROP TABLE IF EXISTS public.profile_updates;
DROP TABLE IF EXISTS public.temporary_passwords;
DROP TABLE IF EXISTS public.email_notifications;
DROP TABLE IF EXISTS public.app_settings;
```

## 📞 Support

If you encounter issues not covered here:

1. **Check the Supabase logs** for detailed error messages
2. **Verify your Supabase project** has the required features enabled
3. **Run the verification queries** to identify what's missing
4. **Use the manual fixes** for specific missing components

---

**Remember**: Always use `SAFE_PROFILE_MANAGEMENT_MIGRATION.sql` instead of the original script to avoid column reference errors!
