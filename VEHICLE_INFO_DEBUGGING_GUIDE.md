# 🔍 Vehicle Info Not Showing - Debugging Guide

**Issue**: Vehicle information not appearing in job history screens even after running SQL update

**Date**: January 2025  
**Reported By**: User  
**Status**: 🔧 TROUBLESHOOTING

---

## 📋 Quick Diagnosis Steps

### Step 1: Verify SQL Was Applied
Run this in Supabase SQL Editor:
```sql
-- Check if RPC function has vehicle fields
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc
WHERE proname = 'get_mechanic_job_history';
```

**Expected**: Function source should include:
- `sr_vehicle_brand text`
- `sr_vehicle_model text`
- `sr_vehicle_plate text`
- `LEFT JOIN vehicles v ON v.id = sr.vehicle_id`

**If NOT found**: Re-run `ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql`

### Step 2: Test RPC Function Directly
```sql
-- Test if RPC returns vehicle data
SELECT 
    id,
    job_title,
    sr_vehicle_brand,
    sr_vehicle_model,
    sr_vehicle_plate
FROM get_mechanic_job_history()
LIMIT 5;
```

**Expected Results**:
- ✅ If vehicle data shows up → SQL is working, problem is in Flutter app
- ❌ If all NULL → Check Step 3

### Step 3: Verify Service Requests Have vehicle_id
```sql
-- Check if service_requests actually have vehicle_id assigned
SELECT 
    sr.id,
    sr.title,
    sr.vehicle_id,
    v.brand_name,
    v.model_name,
    v.plate_number
FROM service_requests sr
LEFT JOIN vehicles v ON v.id = sr.vehicle_id
WHERE sr.customer_id = auth.uid()  -- Or use a specific customer_id
LIMIT 10;
```

**Expected**:
- ✅ If vehicle_id is NOT NULL and vehicle data shows → Data exists
- ❌ If vehicle_id IS NULL → **THIS IS THE PROBLEM!** Service requests don't have vehicles assigned

### Step 4: Check Flutter App Logs

**I've added debug logging to the app. Check the console output:**

1. **In mechanic_history_service.dart**:
   ```
   🚗 Vehicle data from RPC: Toyota Vios - ABC 1234
   ```
   OR
   ```
   ⚠️ No vehicle data in RPC for job: Oil Change (sr_vehicle_brand is null)
   ```

2. **In mechanic_job_history_screen.dart**:
   ```
   🔍 UI Check - Job: Oil Change
      serviceRequest: Instance of 'ServiceRequestData'
      vehicleBrand: Toyota
      vehicleModel: Vios
      vehiclePlate: ABC 1234
   ```

3. **In service_history_screen.dart** (customer):
   ```
   🔍 Customer UI - Service: Oil Change
      vehicles data: {brand_name: Toyota, model_name: Vios, plate_number: ABC 1234}
   ```

---

## 🔧 Common Issues & Solutions

### Issue 1: RPC Function Not Updated
**Symptoms**: 
- SQL query returns NULL for all vehicle fields
- Console shows: `⚠️ No vehicle data in RPC for job`

**Solution**:
```sql
-- Drop and recreate the RPC function
DROP FUNCTION IF EXISTS public.get_mechanic_job_history();

-- Then run the entire ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql file
```

**Verify**:
```sql
-- Should return vehicle data
SELECT sr_vehicle_brand, sr_vehicle_model, sr_vehicle_plate 
FROM get_mechanic_job_history() 
LIMIT 1;
```

---

### Issue 2: Service Requests Missing vehicle_id
**Symptoms**:
- RPC function works but returns NULL vehicle data
- SQL query shows `vehicle_id IS NULL` in service_requests

**Root Cause**: Service requests were created without assigning a vehicle

**Solution A - Assign Vehicles to Existing Requests**:
```sql
-- Example: Link service requests to vehicles by customer
UPDATE service_requests sr
SET vehicle_id = (
    SELECT v.id 
    FROM vehicles v 
    WHERE v.user_id = sr.customer_id 
    LIMIT 1
)
WHERE sr.vehicle_id IS NULL 
AND sr.customer_id IN (SELECT DISTINCT user_id FROM vehicles);
```

**Solution B - Check Request Creation Flow**:
- Verify customer selects a vehicle when creating service request
- Check if `vehicle_id` is being saved in request creation code

---

### Issue 3: Flutter App Not Restarted
**Symptoms**:
- SQL returns data
- Console shows old logs or no vehicle logs

**Solution**:
```bash
# STOP the app completely (not just hot reload)
# Then run:
flutter clean
flutter pub get
flutter run
```

**Why**: Model changes (added vehicleBrand, vehicleModel, vehiclePlate) require full restart

---

### Issue 4: Customer History Different Query
**Symptoms**:
- Mechanic history shows vehicles
- Customer history doesn't

**Check Customer Query**:
The customer screen uses a different query pattern. Verify in `service_history_screen.dart`:

```dart
.select('''
  *,
  shops(shop_name),
  service_categories(name, icon_name),
  reviews(rating, comment),
  invoices(total_amount, status),
  vehicles(brand_name, model_name, plate_number)  // ← THIS MUST BE HERE
''')
```

**Test Directly**:
```sql
SELECT 
    sr.*,
    v.brand_name,
    v.model_name,
    v.plate_number
FROM service_requests sr
LEFT JOIN vehicles v ON v.id = sr.vehicle_id
WHERE sr.customer_id = auth.uid()
LIMIT 5;
```

---

### Issue 5: RLS Policy Blocking vehicles Table
**Symptoms**:
- SQL works in SQL Editor (uses admin privileges)
- App shows NULL (uses RLS policies)

**Check RLS Policies**:
```sql
-- Check if vehicles table has proper RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'vehicles';
```

**Required Policies**:
```sql
-- Allow customers to see their own vehicles
CREATE POLICY "Users can view own vehicles"
ON vehicles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow service providers to see customer vehicles (for job history)
CREATE POLICY "Mechanics can view customer vehicles through service requests"
ON vehicles FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM service_requests sr
        WHERE sr.vehicle_id = vehicles.id
        AND sr.provider_id = auth.uid()
    )
);
```

---

## 🎯 Step-by-Step Troubleshooting

### For Mechanic Job History

1. **Check Database**:
   ```sql
   -- As the mechanic user
   SELECT * FROM get_mechanic_job_history() LIMIT 1;
   ```
   - Look for: `sr_vehicle_brand`, `sr_vehicle_model`, `sr_vehicle_plate`

2. **Check Flutter Console**:
   - Look for: `🚗 Vehicle data from RPC: ...`
   - Or: `⚠️ No vehicle data in RPC for job: ...`

3. **Check UI Logs**:
   - Look for: `🔍 UI Check - Job: ...`
   - Check if `vehicleBrand:` shows a value or null

4. **Visual Check**:
   - Should see green card with car icon between Customer and Location
   - If not visible → check if condition is true: `job.serviceRequest?.vehicleBrand != null`

### For Customer Service History

1. **Check Database**:
   ```sql
   SELECT 
       sr.title,
       sr.vehicle_id,
       v.brand_name,
       v.model_name,
       v.plate_number
   FROM service_requests sr
   LEFT JOIN vehicles v ON v.id = sr.vehicle_id
   WHERE sr.customer_id = auth.uid()
   LIMIT 5;
   ```

2. **Check Flutter Console**:
   - Look for: `🔍 Customer UI - Service: ...`
   - Check if `vehicles data:` shows object or null

3. **Visual Check**:
   - Should see green text with car icon after shop/date row
   - If not visible → check if `service['vehicles'] != null`

---

## 📊 Debug Checklist

Use this checklist to systematically debug the issue:

### Database Level
- [ ] RPC function `get_mechanic_job_history` exists
- [ ] RPC function includes vehicle fields in RETURNS TABLE
- [ ] RPC function includes `LEFT JOIN vehicles v`
- [ ] RPC function SELECT includes `v.brand_name`, `v.model_name`, `v.plate_number`
- [ ] Test query returns vehicle data (not all NULL)
- [ ] service_requests table has `vehicle_id` column
- [ ] service_requests records have non-NULL `vehicle_id` values
- [ ] vehicles table has proper RLS policies
- [ ] Can SELECT from vehicles table as authenticated user

### Flutter App Level
- [ ] ServiceRequestData model has vehicleBrand, vehicleModel, vehiclePlate fields
- [ ] ServiceRequestData.fromJson() maps vehicle fields
- [ ] mechanic_history_service.dart maps sr_vehicle_brand, sr_vehicle_model, sr_vehicle_plate
- [ ] Debug logs appear in console (🚗 or ⚠️ messages)
- [ ] mechanic_job_history_screen.dart has vehicle card code
- [ ] service_history_screen.dart has vehicles join in query
- [ ] service_history_screen.dart has vehicle display code
- [ ] App was fully restarted (not just hot reload)

### UI Level
- [ ] Debug logs show `vehicleBrand:` has value
- [ ] Condition `job.serviceRequest?.vehicleBrand != null` is true
- [ ] Green vehicle card/text visible in UI
- [ ] Car icon displays
- [ ] Vehicle brand and model text shows
- [ ] Plate number displays (if available)

---

## 🚀 Quick Fix Commands

### 1. Re-apply Database Changes
```sql
-- Run this in Supabase SQL Editor
\i ADD_VEHICLE_TO_JOB_HISTORY_RPC.sql
```

### 2. Restart Flutter App
```bash
# In terminal
flutter clean
flutter pub get
flutter run
```

### 3. Force Refresh Data
In the app:
- Pull down to refresh job history
- Navigate away and back to history screen
- Logout and login again

---

## 📸 What You Should See

### Mechanic Job History (Correct)
```
┌────────────────────────────────────────┐
│ 🔧 Oil Change            [Completed]   │
│ 📅 Yesterday                           │
├────────────────────────────────────────┤
│ 👤 Customer Details                    │
│    Juan Dela Cruz                      │
│    📞 092546491630                     │
├────────────────────────────────────────┤
│ 🚗 Vehicle                             │ ← THIS SHOULD APPEAR
│    Toyota Vios                         │
│    📍 ABC 1234                        │
└────────────────────────────────────────┘
```

### Customer Service History (Correct)
```
┌────────────────────────────────────────┐
│ 🔧 Oil Change            [Completed]   │
│    General Service                     │
├────────────────────────────────────────┤
│ 🏪 AutoFix Shop          📅 Yesterday │
│ 🚗 Toyota Vios [ABC 1234]             │ ← THIS SHOULD APPEAR
├────────────────────────────────────────┤
│ Engine oil change...                   │
└────────────────────────────────────────┘
```

---

## 🎯 Most Likely Issue

Based on the symptoms, the **most likely issue** is:

### ❌ **Service Requests Don't Have vehicle_id Assigned**

**Evidence**:
- SQL was run successfully (file created)
- Code was updated (vehicle display logic added)
- But vehicle info not showing

**Root Cause**:
When service requests are created, the `vehicle_id` field is not being populated. This means even though the RPC function and UI code are correct, there's no vehicle data to display.

**Verify This**:
```sql
-- Check how many requests have vehicles
SELECT 
    COUNT(*) as total_requests,
    COUNT(vehicle_id) as requests_with_vehicles,
    COUNT(*) - COUNT(vehicle_id) as requests_without_vehicles
FROM service_requests;
```

**If requests_without_vehicles > 0, this is your issue!**

**Fix**:
1. Update service request creation flow to require vehicle selection
2. Link existing requests to vehicles (see Solution A above)
3. Verify vehicle selection UI exists in request creation screen

---

## 📞 Next Steps

1. **Run the SQL queries in Step 1-3** to identify where the problem is
2. **Check Flutter console logs** for the debug messages I added
3. **Report back** with:
   - Results of Step 2 (does RPC return vehicle data?)
   - Results of Step 3 (do service_requests have vehicle_id?)
   - Console logs (🚗 or ⚠️ messages)

This will help pinpoint exactly where the issue is!

---

**Files Modified for Debugging**:
- `lib/services/mechanic_history_service.dart` - Added debug logging
- `lib/mechanic/mechanic_job_history_screen.dart` - Added debug logging  
- `lib/customer/service_history_screen.dart` - Added debug logging

**To Remove Debug Logs Later**: Search for `🔍` or `Builder(` and remove those debug widgets.
