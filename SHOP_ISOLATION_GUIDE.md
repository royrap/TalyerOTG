# 🏪 Shop-Based Request Isolation - Complete Guide

## 📋 Problema (Problem)

**Current Issue:**
- Customer pinili ang Shop A
- Pero LAHAT ng mechanics makakakita ng request (kahit Shop B, Shop C, etc.)
- Hindi strict ang shop isolation

**Expected Behavior:**
- Customer selects **Shop A** → ONLY mechanics sa Shop A ang makakakita
- Shop B mechanics → **HINDI dapat makita** ang request
- Shop C mechanics → **HINDI dapat makita** ang request

---

## ✅ Solusyon (Solution)

### Key Changes:

1. **Use `shop_id` instead of `preferred_shop_id`**
   - `shop_id` = Actual shop assignment (canonical field)
   - `preferred_shop_id` = Customer preference only

2. **Strict Shop Isolation**
   - Function checks `shop_mechanics` table
   - MUST match: `shop_mechanics.shop_id = service_requests.shop_id`
   - If no match → mechanic CANNOT see request

3. **Clear Visibility Rules**
   ```
   IF request.shop_id = 'Shop A ID'
      AND mechanic.shop_id = 'Shop A ID'
      THEN ✅ Visible
   
   IF request.shop_id = 'Shop A ID'
      AND mechanic.shop_id = 'Shop B ID'
      THEN ❌ Hidden
   ```

---

## 🚀 Deployment Steps

### Step 1: Run SQL Fix
```sql
-- Run this in Supabase SQL Editor
-- File: FIX_SHOP_ISOLATION_COMPLETE.sql
```

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Paste entire contents of `FIX_SHOP_ISOLATION_COMPLETE.sql`
4. Click **Run**
5. Check for success messages:
   - ✅ Function exists
   - ✅ Shop isolation active

### Step 2: Verify Shop Assignments
Make sure your mechanics are assigned to shops in `shop_mechanics` table:

```sql
-- Check mechanic assignments
SELECT 
    m.id as mechanic_id,
    up.first_name || ' ' || up.last_name as mechanic_name,
    s.shop_name,
    sm.is_active
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.id
LEFT JOIN shops s ON s.id = sm.shop_id
WHERE sm.is_active = true
ORDER BY s.shop_name;
```

**If mechanics are not assigned:**
```sql
-- Assign mechanic to shop
INSERT INTO shop_mechanics (mechanic_id, shop_id, is_active)
VALUES 
    ('MECHANIC_ID', 'SHOP_ID', true);
```

### Step 3: Restart Flutter App
```powershell
# In your terminal
flutter run
```

---

## 🧪 Testing Shop Isolation

### Test Scenario 1: Mechanic from Correct Shop
```sql
-- Test mechanic who BELONGS to the selected shop
SELECT * FROM get_nearby_requests_for_mechanic(
    'MECHANIC_A_ID'::uuid,  -- Mechanic from Shop A
    14.6507,  -- Latitude
    121.0494,  -- Longitude
    50.0  -- Max distance
);

-- ✅ Expected: Should see Shop A requests
```

### Test Scenario 2: Mechanic from Different Shop
```sql
-- Test mechanic who DOES NOT belong to the selected shop
SELECT * FROM get_nearby_requests_for_mechanic(
    'MECHANIC_B_ID'::uuid,  -- Mechanic from Shop B
    14.6507,
    121.0494,
    50.0
);

-- ❌ Expected: Should NOT see Shop A requests
```

### Test Scenario 3: Live Test
1. **Login as Customer**
   - Select Shop A from shop list
   - Create a service request
   - Note the request ID

2. **Login as Mechanic A** (assigned to Shop A)
   - Open mechanic dashboard
   - Check nearby requests
   - ✅ Should see the request

3. **Login as Mechanic B** (assigned to Shop B)
   - Open mechanic dashboard
   - Check nearby requests
   - ❌ Should NOT see the request

---

## 🔍 Verification Queries

### Check Current Shop-Based Requests
```sql
SELECT 
    sr.id,
    sr.request_type,
    sr.shop_id,
    s.shop_name,
    sr.status,
    COUNT(DISTINCT sm.mechanic_id) as mechanics_in_shop
FROM service_requests sr
LEFT JOIN shops s ON sr.shop_id = s.id
LEFT JOIN shop_mechanics sm ON sm.shop_id = sr.shop_id AND sm.is_active = true
WHERE sr.request_type = 'shop_based'
AND sr.status IN ('pending', 'awaiting_payment', 'ready_to_assign')
GROUP BY sr.id, sr.request_type, sr.shop_id, s.shop_name, sr.status
ORDER BY sr.created_at DESC;
```

### Check Function Shop Isolation Logic
```sql
-- Verify function uses shop_id matching
SELECT 
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%sm.shop_id = dc.shop_id%' 
        THEN '✅ Shop isolation ACTIVE'
        ELSE '❌ Shop isolation MISSING'
    END as status
FROM pg_proc
WHERE proname = 'get_nearby_requests_for_mechanic';
```

### Check Mechanic-Shop Assignments
```sql
-- See which mechanics belong to which shops
SELECT 
    s.shop_name,
    up.first_name || ' ' || up.last_name as mechanic_name,
    sm.is_active,
    mas.current_status
FROM shop_mechanics sm
INNER JOIN shops s ON s.id = sm.shop_id
INNER JOIN mechanics m ON m.id = sm.mechanic_id
INNER JOIN user_profiles up ON up.id = m.user_id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
WHERE sm.is_active = true
ORDER BY s.shop_name, up.first_name;
```

---

## 🐛 Troubleshooting

### Problem: Mechanic can't see ANY requests
**Possible Causes:**
1. Mechanic not assigned to any shop
2. Mechanic status not 'available'
3. shop_mechanics.is_active = false

**Solution:**
```sql
-- Check mechanic status
SELECT 
    m.id,
    up.first_name || ' ' || up.last_name as name,
    sm.shop_id,
    sm.is_active as shop_active,
    mas.current_status,
    mas.is_accepting_requests
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = m.id
WHERE m.user_id = 'YOUR_MECHANIC_USER_ID';

-- Fix if needed
UPDATE shop_mechanics SET is_active = true WHERE mechanic_id = 'MECHANIC_ID';
UPDATE mechanic_availability_status 
SET current_status = 'available', is_accepting_requests = true 
WHERE mechanic_id = 'MECHANIC_ID';
```

### Problem: Mechanic sees requests from wrong shops
**Possible Causes:**
1. Old function version still cached
2. shop_id not set on service_requests

**Solution:**
```sql
-- Force refresh function
DROP FUNCTION IF EXISTS get_nearby_requests_for_mechanic(UUID, NUMERIC, NUMERIC, NUMERIC);
-- Then re-run FIX_SHOP_ISOLATION_COMPLETE.sql

-- Set shop_id for existing requests
UPDATE service_requests 
SET shop_id = preferred_shop_id
WHERE request_type = 'shop_based'
AND shop_id IS NULL
AND preferred_shop_id IS NOT NULL;
```

### Problem: shop_id is NULL on requests
**Possible Causes:**
1. Customer app not sending shop_id
2. Old request format

**Solution:**
Check customer app sends shop_id:
```dart
// In service_request_service.dart
'shop_id': selectedShopId,  // Must be set!
'request_type': 'shop_based',
```

---

## 📊 Data Flow

### Request Creation Flow:
```
1. Customer opens app
   ↓
2. Customer selects "Shop A" from list
   ↓
3. Customer creates request
   ↓
4. service_requests table receives:
   - request_type = 'shop_based'
   - shop_id = 'Shop A ID'  ✅ KEY FIELD
   - preferred_shop_id = 'Shop A ID'
   ↓
5. get_nearby_requests_for_mechanic runs for each mechanic
   ↓
6. Function checks:
   IF request.shop_id = mechanic.shop_id
      AND mechanic.is_active = true
      AND mechanic.status = 'available'
   THEN show request
   ↓
7. ONLY Shop A mechanics see the request ✅
```

### Visibility Matrix:
```
Request Created For: Shop A (shop_id = 'A')

Mechanic    | Shop Assignment | Can See? | Reason
------------|-----------------|----------|---------------------------
Mechanic 1  | Shop A          | ✅ YES   | shop_id matches
Mechanic 2  | Shop B          | ❌ NO    | Different shop_id
Mechanic 3  | Shop A          | ✅ YES   | shop_id matches
Mechanic 4  | Shop C          | ❌ NO    | Different shop_id
Mechanic 5  | No assignment   | ❌ NO    | Not in shop_mechanics
```

---

## 📝 Summary

### What Changed:
1. ✅ Function now uses `shop_id` (not `preferred_shop_id`)
2. ✅ Strict matching: `shop_mechanics.shop_id = service_requests.shop_id`
3. ✅ Added shop_id to function return columns
4. ✅ Auto-backfill shop_id from preferred_shop_id

### Expected Behavior:
- **Shop A request** → Only Shop A mechanics see it
- **Shop B request** → Only Shop B mechanics see it
- **Broadcast request** → All nearby mechanics see it

### Deployment Checklist:
- [ ] Run `FIX_SHOP_ISOLATION_COMPLETE.sql`
- [ ] Verify all mechanics are assigned to shops
- [ ] Restart Flutter app
- [ ] Test with mechanics from different shops
- [ ] Verify shop isolation working

---

## 🎯 Success Criteria

✅ Shop isolation is working if:
1. Mechanic from Shop A can see Shop A requests
2. Mechanic from Shop B **CANNOT** see Shop A requests
3. Mechanic from Shop A **CANNOT** see Shop B requests
4. All mechanics can see broadcast requests
5. Function returns shop_id in results

---

**Need help?** Check the verification queries above or test with the provided SQL commands.
