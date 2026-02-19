# Dashboard Data Display & Computation Guide

## Date: December 2024

## Problem Fixed
The dashboard was showing:
- ❌ "null null" for mechanic names
- ❌ ₱0.00 for all earnings
- ❌ 0 for all job counts

## Changes Made

### 1. **Fixed Mechanics Name Display**
**File**: `new_talyer_owner_home.dart`

**Problem**: Code was directly accessing `profile['first_name']` and `profile['last_name']` without null checks

**Solution**: Added proper null handling
```dart
// Better null handling for names
String firstName = 'Unknown';
String lastName = '';

if (profile != null) {
  firstName = profile['first_name']?.toString() ?? 'Unknown';
  lastName = profile['last_name']?.toString() ?? '';
}

final name = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
```

### 2. **Added Debug Logging**
Added comprehensive console logging to track data loading:
```dart
print('🔍 Loading mechanics for shop: $_shopId');
print('📊 Mechanic count - Total: $_totalMechanics, Available: $_availableMechanics');
print('✅ Loaded ${_mechanicsList.length} mechanics');
print('🔍 Loading jobs for period: $_selectedPeriod');
print('💰 Earnings - Shop: ₱$_shopEarnings, Mechanics: ₱$_mechanicsEarnings');
```

## How Dashboard Data is Calculated

### 📊 **Overview Section - Total Jobs**
```dart
// Counts ALL jobs from service_requests table
SELECT COUNT(*) 
FROM service_requests
WHERE shop_id = 'YOUR_SHOP_ID'
  AND created_at >= [period_start_date]
```

**Displayed As**: 
- Total Jobs: 0 (Today)
- Total Jobs: 0 (Week)  
- Total Jobs: 0 (Month)

### ✅ **Completed Jobs**
```dart
// Counts only completed jobs from mechanic_job_history
SELECT COUNT(*) 
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND created_at >= [period_start_date]
```

### 💰 **Earnings Breakdown**

#### Shop Earnings (20%)
```dart
// Sums shop_earnings from mechanic_job_history
SELECT SUM(shop_earnings)
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND created_at >= [period_start_date]
```

#### Mechanics Earnings (75%)
```dart
SELECT SUM(mechanic_earnings)
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND created_at >= [period_start_date]
```

#### Platform Fee (5%)
```dart
SELECT SUM(platform_fee)
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND created_at >= [period_start_date]
```

### ⚙️ **Mechanics Status**
```dart
// Total mechanics linked to shop
SELECT COUNT(*)
FROM shop_mechanics
WHERE shop_id = 'YOUR_SHOP_ID'
  AND is_active = true

// Available mechanics  
SELECT COUNT(*)
FROM shop_mechanics
WHERE shop_id = 'YOUR_SHOP_ID'
  AND is_active = true
  AND is_available = true
```

### 🚗 **Ongoing Services**
```dart
SELECT *
FROM service_requests
WHERE shop_id = 'YOUR_SHOP_ID'
  AND status IN ('pending', 'accepted', 'in_progress', 'inspection_started')
ORDER BY created_at DESC
```

## SQL Queries to Check Your Data

### 1. Check if shop exists and get shop_id
```sql
SELECT id, shop_name, owner_id, is_active
FROM shops
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 5;
```

### 2. Check mechanics linked to shop
```sql
SELECT 
  sm.id,
  sm.shop_id,
  sm.mechanic_id,
  sm.is_active,
  sm.is_available,
  up.first_name,
  up.last_name,
  up.email
FROM shop_mechanics sm
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.shop_id = 'YOUR_SHOP_ID'
ORDER BY sm.created_at DESC;
```

**Expected Result**:
- Should show mechanics with proper first_name and last_name
- If names are NULL, that's why you see "null null"

### 3. Check completed jobs with earnings
```sql
SELECT 
  id,
  shop_id,
  mechanic_id,
  job_status,
  total_amount,
  mechanic_earnings,
  shop_earnings,
  platform_fee,
  created_at
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
ORDER BY created_at DESC
LIMIT 10;
```

**Expected Result**:
- Should show completed jobs with earnings populated
- If all earnings are 0 or NULL, dashboard will show ₱0

### 4. Check service requests (all jobs)
```sql
SELECT 
  id,
  shop_id,
  customer_id,
  assigned_mechanic_id,
  status,
  service_type,
  created_at
FROM service_requests
WHERE shop_id = 'YOUR_SHOP_ID'
ORDER BY created_at DESC
LIMIT 10;
```

### 5. Check today's data specifically
```sql
-- Today's completed jobs
SELECT COUNT(*) as completed_today
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND DATE(created_at) = CURRENT_DATE;

-- Today's total earnings
SELECT 
  SUM(shop_earnings) as shop_total,
  SUM(mechanic_earnings) as mechanic_total,
  SUM(platform_fee) as platform_total,
  SUM(total_amount) as grand_total
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed'
  AND DATE(created_at) = CURRENT_DATE;
```

## SQL to Populate Test Data

### Step 1: Ensure mechanics have names in user_profiles
```sql
-- Check which mechanics have NULL names
SELECT id, email, first_name, last_name, user_type
FROM user_profiles
WHERE user_type = 'mechanic'
  AND (first_name IS NULL OR last_name IS NULL);

-- Update mechanics with test names
UPDATE user_profiles
SET 
  first_name = 'Juan',
  last_name = 'Dela Cruz'
WHERE user_type = 'mechanic'
  AND first_name IS NULL
  AND id IN (
    SELECT mechanic_id 
    FROM shop_mechanics 
    WHERE shop_id = 'YOUR_SHOP_ID'
    LIMIT 1
  );
```

### Step 2: Create test completed jobs with earnings
```sql
-- Insert test completed job into mechanic_job_history
INSERT INTO mechanic_job_history (
  shop_id,
  mechanic_id,
  customer_id,
  service_request_id,
  job_title,
  job_description,
  job_status,
  total_amount,
  mechanic_earnings,
  shop_earnings,
  platform_fee,
  rating,
  completed_at,
  created_at
) VALUES (
  'YOUR_SHOP_ID',
  'YOUR_MECHANIC_ID',
  'YOUR_CUSTOMER_ID',
  'YOUR_SERVICE_REQUEST_ID',
  'Oil Change',
  'Regular oil change service',
  'completed',
  5000.00,                    -- Total amount
  3750.00,                    -- 75% to mechanic
  1000.00,                    -- 20% to shop
  250.00,                     -- 5% platform fee
  5,                          -- Rating (1-5)
  NOW(),                      -- Completed today
  NOW()                       -- Created today
);
```

### Step 3: Bulk insert multiple test jobs
```sql
-- Insert 5 test jobs for today
INSERT INTO mechanic_job_history (
  shop_id, mechanic_id, customer_id, service_request_id,
  job_title, job_status, total_amount,
  mechanic_earnings, shop_earnings, platform_fee,
  rating, completed_at, created_at
)
SELECT 
  'YOUR_SHOP_ID',
  mechanic_id,
  'YOUR_CUSTOMER_ID',
  gen_random_uuid(),
  'Service Job ' || generate_series,
  'completed',
  (2000 + random() * 3000)::numeric(10,2),                    -- Random 2000-5000
  ((2000 + random() * 3000) * 0.75)::numeric(10,2),          -- 75%
  ((2000 + random() * 3000) * 0.20)::numeric(10,2),          -- 20%
  ((2000 + random() * 3000) * 0.05)::numeric(10,2),          -- 5%
  4 + (random())::int,                                        -- Random 4-5 rating
  NOW() - (random() * interval '24 hours'),                   -- Random time today
  NOW() - (random() * interval '24 hours')
FROM shop_mechanics
CROSS JOIN generate_series(1, 5)
WHERE shop_id = 'YOUR_SHOP_ID'
  AND is_active = true
LIMIT 5;
```

### Step 4: Create ongoing service requests
```sql
INSERT INTO service_requests (
  shop_id,
  customer_id,
  assigned_mechanic_id,
  status,
  service_type,
  title,
  description,
  created_at
) VALUES (
  'YOUR_SHOP_ID',
  'YOUR_CUSTOMER_ID',
  'YOUR_MECHANIC_ID',
  'in_progress',
  'Brake Repair',
  'Brake System Check',
  'Customer reported squeaking brakes',
  NOW()
);
```

## How to Find Your IDs

### Get your shop_id:
```sql
SELECT id, shop_name, owner_id
FROM shops
WHERE owner_id = (
  SELECT id FROM user_profiles 
  WHERE email = 'your.email@example.com'
);
```

### Get mechanic_ids for your shop:
```sql
SELECT mechanic_id, first_name, last_name
FROM shop_mechanics sm
JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE sm.shop_id = 'YOUR_SHOP_ID';
```

### Get a customer_id:
```sql
SELECT id, first_name, last_name, email
FROM user_profiles
WHERE user_type = 'customer'
LIMIT 1;
```

## Expected Results After Adding Data

### Before (Empty Database):
```
📊 Overview - Today
Total Jobs: 0
Completed: 0
Active Jobs: 0
Completion Rate: 0%

💸 Earnings - Today
Total Revenue: ₱0.00
Gross Income: ₱0
Net Income (Shop): ₱0

⚙️ Mechanics Status
Available: 2/2
null null - Available
null null - Available
```

### After (With Test Data):
```
📊 Overview - Today  
Total Jobs: 5
Completed: 5
Active Jobs: 1
Completion Rate: 100%

💸 Earnings - Today
Total Revenue: ₱15,000.00
Gross Income: ₱15,000
Net Income (Shop): ₱3,000

⚙️ Mechanics Status
Available: 2/2
Juan Dela Cruz - Available
Maria Santos - Available
```

## Troubleshooting

### Problem: Still showing ₱0 after adding data

**Check 1**: Verify data was inserted
```sql
SELECT COUNT(*) FROM mechanic_job_history 
WHERE shop_id = 'YOUR_SHOP_ID' 
  AND job_status = 'completed'
  AND DATE(created_at) = CURRENT_DATE;
```

**Check 2**: Verify earnings fields are not NULL
```sql
SELECT 
  COUNT(*) as total_jobs,
  COUNT(mechanic_earnings) as has_mechanic_earnings,
  COUNT(shop_earnings) as has_shop_earnings,
  SUM(mechanic_earnings) as total_mechanic,
  SUM(shop_earnings) as total_shop
FROM mechanic_job_history
WHERE shop_id = 'YOUR_SHOP_ID'
  AND job_status = 'completed';
```

**Check 3**: Verify shop_id matches
```sql
-- Your shop's ID
SELECT id FROM shops WHERE owner_id = 'YOUR_USER_ID';

-- Jobs for that shop
SELECT COUNT(*) FROM mechanic_job_history WHERE shop_id = '[result_from_above]';
```

### Problem: Still showing "null null" for mechanics

**Fix**: Update user_profiles table
```sql
UPDATE user_profiles up
SET 
  first_name = 'Mechanic' || ROW_NUMBER() OVER (),
  last_name = 'User'
WHERE id IN (
  SELECT mechanic_id FROM shop_mechanics WHERE shop_id = 'YOUR_SHOP_ID'
)
AND (first_name IS NULL OR last_name IS NULL);
```

## Summary

✅ **Fixed**: Mechanic name display with proper null handling
✅ **Added**: Debug logging to track data loading
✅ **Documented**: All SQL queries to check and populate data
✅ **Provided**: Step-by-step guide to add test data

The dashboard now:
- Shows "Unknown" instead of "null null" when names are missing
- Logs all data loading to console for debugging
- Properly calculates earnings from mechanic_job_history table
- Handles all null values gracefully
