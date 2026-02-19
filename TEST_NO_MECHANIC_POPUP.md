# 🧪 PAANO I-TEST ANG NO MECHANIC POP-UP ALERT

## ✅ COMPLETE FIX INSTALLED!

Naka-install na ang complete fix para sa "No Mechanics Available" pop-up alert:

### 1️⃣ SQL FIX (Backend) - FIX_SHOP_SPECIFIC_ROUTING.sql
✅ **KAILANGAN MO PA RUN ITO SA SUPABASE!**

### 2️⃣ FLUTTER FIX (Frontend) - vehicle_details_screen.dart
✅ **NA-INSTALL NA!** (just now)

---

## 📋 PRE-TEST CHECKLIST

### Step 1: I-verify na walang mechanic sa "riza store"

```sql
-- Run sa Supabase SQL Editor
SELECT 
    s.shop_name,
    COUNT(sm.mechanic_id) as mechanic_count
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
WHERE s.shop_name ILIKE '%riza%'
GROUP BY s.id, s.shop_name;
```

**Expected Result:**
```
shop_name    | mechanic_count
-------------|---------------
riza store   | 0
```

✅ **If 0 mechanics** - Perfect! Pwede na mag-test
❌ **If may mechanics** - I-deactivate muna temporarily

### Step 2: Run SQL Fix (ONE TIME ONLY)

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy entire FIX_SHOP_SPECIFIC_ROUTING.sql (506 lines)
4. Paste and click **RUN**
5. Wait for "Success. No rows returned"

**Verification:**
```sql
-- Check if functions are installed
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN (
    'broadcast_service_request_with_shop_filter',
    'find_available_mechanics_in_shop',
    'check_shop_mechanic_availability'
)
AND routine_schema = 'public';
```

**Expected:** 3 rows (3 functions installed)

---

## 🧪 TESTING STEPS

### TEST CASE 1: Shop WITHOUT Mechanics (PRIMARY TEST)

**Setup:**
- Shop: "riza store" 
- Mechanics: 0
- Customer: Mag-request ng service

**Steps:**

1. **Customer side:**
   - Open RoadAid app
   - Login as customer
   - Click "Request Assistance"
   - Select **"riza store"** shop
   - Fill in vehicle details
   - Click "Submit Request"

2. **Expected Behavior:**

   ✅ **Pop-up alert dapat lumabas:**
   
   ```
   ⚠️ No Mechanics Available
   
   Sorry, there are no mechanics in the 
   selected shop. Please try another shop.
   
   💡 Suggestions:
   • Select another shop
   • Try again later
   • Use broadcast mode (any available mechanic)
   
   [CANCEL]  [SELECT ANOTHER SHOP]
   ```

3. **Expected Results:**
   - ✅ Pop-up alert appears immediately
   - ✅ "SELECT ANOTHER SHOP" button returns to shop selection
   - ✅ NO navigation to "Finding Mechanic" screen
   - ✅ NO notification sent to mechanics from other shops
   - ✅ Service request created with `broadcast_status = 'no_mechanics_available'`

4. **What should NOT happen:**
   - ❌ NO "Finding Your Mechanic" loading screen
   - ❌ NO mechanics from other shops receive notification
   - ❌ NO error message in console

---

### TEST CASE 2: Shop WITH Available Mechanics (Control Test)

**Setup:**
- Shop: Any shop with available mechanics
- Mechanics: 1 or more, status = 'available'

**Steps:**

1. Customer selects shop with mechanics
2. Submit request

**Expected:**
- ✅ NO pop-up alert
- ✅ Navigate to "Finding Your Mechanic" screen
- ✅ Mechanic from THAT SHOP ONLY receives notification
- ✅ Service request has `broadcast_status = 'broadcasting'`

---

### TEST CASE 3: Shop with ALL BUSY Mechanics

**Setup:**
- Shop: Has mechanics but all are busy
- Mechanics: 2+, all status = 'busy' or 'in_service'

**Steps:**

1. Temporarily set all mechanics to busy:
   ```sql
   UPDATE mechanic_availability_status 
   SET current_status = 'busy'
   WHERE mechanic_id IN (
       SELECT mechanic_id 
       FROM shop_mechanics 
       WHERE shop_id = 'YOUR_SHOP_ID'
   );
   ```

2. Customer selects that shop
3. Submit request

**Expected:**
- ✅ Pop-up alert appears
- ✅ Message: "All X mechanics in this shop are currently busy. Please wait or select another shop."
- ✅ NO navigation to waiting screen
- ✅ NO mechanics from other shops notified

---

## 🔍 DEBUGGING TIPS

### If pop-up DOESN'T appear:

1. **Check console logs:**
   ```
   🔍 Checking broadcast status:
     - broadcast_status: no_mechanics_available
     - error: no_available_mechanics
     - success: false
     - user_message: Sorry, there are no mechanics...
   ```

2. **If you see "broadcast_status: broadcasting"** - SQL fix not installed yet!
   - Run FIX_SHOP_SPECIFIC_ROUTING.sql in Supabase

3. **If you see "broadcast_status: null"** - Trigger not working
   - Check if trigger is installed:
     ```sql
     SELECT trigger_name 
     FROM information_schema.triggers 
     WHERE trigger_name = 'auto_broadcast_new_request';
     ```

4. **If Flutter hot reload doesn't work:**
   - Stop app (Ctrl+C in terminal)
   - Run `flutter run` again

### If mechanics from OTHER shops still receive notification:

1. **Check service_requests table:**
   ```sql
   SELECT 
       id,
       preferred_shop_id,
       request_type,
       broadcast_status,
       notified_providers_count
   FROM service_requests
   WHERE customer_id = 'YOUR_CUSTOMER_ID'
   ORDER BY created_at DESC
   LIMIT 5;
   ```

2. **Expected:**
   - `preferred_shop_id`: NOT NULL (shop ID ng riza store)
   - `request_type`: 'shop_based'
   - `broadcast_status`: 'no_mechanics_available'
   - `notified_providers_count`: 0

3. **If broadcast_status = 'broadcasting':**
   - SQL function not working correctly
   - Re-run FIX_SHOP_SPECIFIC_ROUTING.sql

---

## ✅ SUCCESS CRITERIA

Test is **SUCCESSFUL** if:

1. ✅ Pop-up alert appears when selecting shop with 0 mechanics
2. ✅ Pop-up shows correct message from database
3. ✅ "SELECT ANOTHER SHOP" button works
4. ✅ NO mechanics from other shops receive notification
5. ✅ NO navigation to "Finding Mechanic" screen
6. ✅ Database shows `broadcast_status = 'no_mechanics_available'`

---

## 📱 SCREENSHOTS TO VERIFY

Kunin ang screenshot ng:

1. **Pop-up Alert** - Showing "No Mechanics Available" message
2. **Customer Console** - Showing debug logs
3. **Mechanic Side** - Should show NO notification
4. **Supabase Dashboard** - service_requests table showing broadcast_status

---

## 🔧 TROUBLESHOOTING

### Issue: Hot reload doesn't pick up changes

**Solution:**
```powershell
# Stop app
Ctrl+C

# Restart app
flutter run
```

### Issue: SQL functions not installed

**Solution:**
1. Open Supabase SQL Editor
2. Run entire FIX_SHOP_SPECIFIC_ROUTING.sql file
3. Wait for success message
4. Verify with:
   ```sql
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_name LIKE '%shop%' OR routine_name LIKE '%mechanic%';
   ```

### Issue: Still showing old behavior

**Solution:**
1. Clear app data (if possible)
2. Full restart: `flutter clean` then `flutter run`
3. Check if SQL fix is installed (see verification query above)
4. Check if Flutter changes were saved (Ctrl+S)

---

## 📞 NEED HELP?

If issue persists:

1. Copy console output (all logs)
2. Screenshot ng pop-up (or lack of pop-up)
3. Run this query and share result:
   ```sql
   SELECT * FROM service_requests 
   WHERE id = 'YOUR_REQUEST_ID'::uuid;
   ```
4. Check Supabase logs for errors

---

## 🎯 NEXT STEPS AFTER TESTING

After successful test:

1. ✅ Mark test as passed
2. ✅ Test with different shops
3. ✅ Test with busy mechanics scenario
4. ✅ Test normal flow (shop with available mechanics)
5. ✅ Deploy to production

---

**IMPORTANT:** Make sure to run SQL fix sa Supabase BEFORE testing!

```sql
-- Run this in Supabase SQL Editor
-- Copy entire FIX_SHOP_SPECIFIC_ROUTING.sql file
```

Good luck! 🚀
