# 🚀 RoadAid Database Deployment Guide

## 📋 Overview
This guide helps you deploy the new system enhancements to your existing RoadAid database safely and correctly.

## 🔍 Pre-Deployment Checklist

### 1. Backup Your Database
```sql
-- Create a backup before running any scripts
pg_dump your_database_name > backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Verify Current Database State
Check that your database has these core tables (which I can see it does):
- `user_profiles` ✅
- `service_requests` ✅  
- `notifications` ✅
- `shops` ✅
- `vehicles` ✅

## 📦 Deployment Order

Execute the SQL scripts in this exact order:

### Step 1: ETA Tracking Setup
```bash
# This adds columns to existing service_requests table
psql -d your_database -f ETA_TRACKING_DATABASE_SETUP.sql
```

**What this does:**
- Adds `current_eta_minutes`, `current_distance_km`, `traffic_condition`, `eta_last_updated` columns
- Creates helper functions for ETA management
- No existing data is affected

### Step 2: Photo Progress System
```bash
# This creates new tables for photo progress tracking
psql -d your_database -f PHOTO_PROGRESS_DATABASE_SETUP.sql
```

**What this does:**
- Creates `progress_photos` table
- Creates `service_phase_tracking` table
- Sets up RLS policies compatible with your existing structure
- Creates notification triggers

### Step 3: Smart Notifications System
```bash
# This creates advanced notification infrastructure
psql -d your_database -f SMART_NOTIFICATIONS_DATABASE_SETUP.sql
```

**What this does:**
- Creates `notification_templates` with predefined templates
- Creates `user_notification_preferences` table
- Creates `notification_delivery_log` for analytics
- Creates `do_not_disturb_settings` table
- Sets up smart filtering functions

## 🔧 Key Compatibility Changes Made

### 1. User References Fixed
- Changed `mechanics` table references to `user_profiles` 
- Updated foreign keys to match your existing schema
- Fixed user type constraints to match your enum values

### 2. Notification Schema Alignment
- Updated to work with your existing `notifications` table structure
- Removed columns that don't exist in your schema
- Fixed RLS policies for your auth system

### 3. ID Generation
- Changed from `uuid_generate_v4()` to `gen_random_uuid()` to match your existing tables

## 📊 Verification Queries

After deployment, run these to verify everything works:

```sql
-- Check new columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'service_requests' 
  AND column_name IN ('current_eta_minutes', 'current_distance_km', 'traffic_condition');

-- Check new tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('progress_photos', 'service_phase_tracking', 'notification_templates');

-- Test ETA functions
SELECT update_service_eta(
  (SELECT id FROM service_requests LIMIT 1),
  15, 5.2, 'moderate'
);

-- Test photo progress functions
SELECT get_current_service_phase((SELECT id FROM service_requests LIMIT 1));

-- Test notification templates
SELECT COUNT(*) FROM notification_templates;
```

## 🔒 Security Notes

### RLS Policies Updated
All new tables have Row Level Security enabled with policies that:
- Allow users to see only their own data
- Prevent unauthorized access
- Work with your existing auth system

### Permissions Granted
```sql
-- All necessary permissions are granted to 'authenticated' role
-- This matches your existing permission structure
```

## 🚨 Troubleshooting

### If you get foreign key errors:
```sql
-- Check if user_profiles table exists and has correct structure
\d user_profiles
```

### If you get auth errors:
```sql
-- The scripts now use user_profiles instead of auth.users for most references
-- This matches your existing schema pattern
```

### If notification triggers fail:
```sql
-- Check that your notifications table structure matches:
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'notifications';
```

## ⚡ Quick Test

After deployment, test the integration:

```sql
-- 1. Test ETA tracking
INSERT INTO service_requests (customer_id, title, description, pickup_latitude, pickup_longitude)
VALUES (
  (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
  'Test ETA Request',
  'Testing ETA functionality',
  14.5995, 120.9842
);

-- 2. Test photo progress
SELECT add_progress_photo(
  (SELECT id FROM service_requests ORDER BY created_at DESC LIMIT 1),
  (SELECT id FROM user_profiles WHERE user_type = 'mechanic' LIMIT 1),
  'arrival',
  'https://example.com/test-photo.jpg',
  'Mechanic has arrived at the location'
);

-- 3. Test smart notifications
SELECT send_smart_notification(
  (SELECT id FROM user_profiles WHERE user_type = 'customer' LIMIT 1),
  'customer',
  'eta_update',
  '{"eta_minutes": "15", "mechanic_name": "Test Mechanic"}'::jsonb
);
```

## 🎉 Success Indicators

You'll know the deployment succeeded when:

1. ✅ All SQL scripts run without errors
2. ✅ New tables appear in your database
3. ✅ ETA columns are added to service_requests  
4. ✅ Test queries return expected results
5. ✅ No existing functionality is broken

## 📞 Need Help?

If you encounter any issues:
1. Check the error messages carefully
2. Verify your database user has necessary permissions
3. Ensure all referenced tables exist
4. Run the verification queries above

The system is now ready for the Flutter app integration! 🚀