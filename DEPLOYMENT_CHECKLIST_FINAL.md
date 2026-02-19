# 🎯 COMPLETE DEPLOYMENT CHECKLIST

## 📋 **Current Status:**

You have **3 critical errors** preventing mechanics from accepting requests:

1. ❌ **"Service request not found"** - RLS blocking queries
2. ❌ **"PGRST116: 0 rows returned"** - RLS blocking function
3. ❌ **"Shop isolation violation"** - Mechanic not assigned to shop

---

## 🚀 **3-Step Fix (In Order):**

### **Step 1: Fix RLS Policies** ⭐ **MOST CRITICAL**
**File:** `FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql`

**What it fixes:**
- ✅ "Service request not found" error
- ✅ "PGRST116: 0 rows" error
- ✅ Mechanics can query requests

**How to deploy:**
```sql
-- Open Supabase Dashboard → SQL Editor
-- Copy entire file
-- Click Run
-- Look for: ✅ RLS policies relaxed for function access
```

**Verification:**
```sql
-- Test query - should work without errors
SELECT * FROM get_nearby_requests_for_mechanic(
    'e4cbf14b-5729-45ef-a124-1f2e05acad8c'::uuid,
    14.932127::numeric,
    120.880688::numeric,
    50.0::numeric
);
```

---

### **Step 2: Assign Mechanic to Shop**
**File:** `ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql`

**What it fixes:**
- ✅ "Shop isolation violation" error
- ✅ Mechanic can accept requests

**How to deploy:**
```sql
-- Open Supabase Dashboard → SQL Editor
-- Copy entire file  
-- Click Run
-- Look for: ✅ Mechanic assigned to MechAid supply!
```

**Verification:**
```sql
-- Check assignment
SELECT 
    m.user_id,
    s.shop_name,
    sm.is_active
FROM mechanics m
INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
INNER JOIN shops s ON s.id = sm.shop_id
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- Expected: MechAid supply, is_active: true ✅
```

---

### **Step 3: Restart Flutter App**
```powershell
# In terminal
flutter run
```

**Expected logs:**
```
✅ Mechanic is now online and accepting requests
🎯 Found 1 nearby eligible requests
📬 New request received: <request-id> - showing popup
```

---

## 🧪 **Testing Flow:**

### **Test 1: Customer Creates Request**
1. Login as **customer**
2. Select **"MechAid supply"** from shop list
3. Select service (e.g., "Electrical")
4. Click **"Submit Request"**

**Expected customer logs:**
```
✅ Service request created: <request-id>
- shop_id: cedc2e63-7785-4d61-a8f1-9f4ed8d254da
- request_type: shop_based
```

### **Test 2: Mechanic Sees Request**
1. Login as **mechanic** (user: e4cbf14b-5729-45ef-a124-1f2e05acad8c)
2. Dashboard should **auto-refresh**
3. **Popup should appear** with request details

**Expected mechanic logs:**
```
🎯 Found 1 nearby eligible requests
📬 New request received: <request-id> - showing popup
✅ Request loaded successfully
```

### **Test 3: Mechanic Accepts Request**
1. Click **"Accept"** button
2. Request should be **assigned**

**Expected logs:**
```
🔧 Starting acceptance process...
✅ Request accepted successfully
✅ Status: assigned
```

**Should NOT see:**
```
❌ Service request not found  ← FIXED
❌ PGRST116: 0 rows  ← FIXED
❌ Shop isolation violation  ← FIXED
```

---

## 🔍 **Troubleshooting:**

### **Issue: Still getting "Service request not found"**
**Solution:**
```sql
-- Check if RLS is disabled
SELECT rowsecurity FROM pg_tables WHERE tablename = 'service_requests';
-- Should be: true

-- Check policies
SELECT policyname FROM pg_policies WHERE tablename = 'service_requests';
-- Should have: 4 policies

-- Re-run: FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql
```

### **Issue: Still getting "Shop isolation violation"**
**Solution:**
```sql
-- Check mechanic assignment
SELECT 
    m.user_id,
    sm.shop_id,
    sm.is_active
FROM mechanics m
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = m.id
WHERE m.user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

-- If shop_id is NULL or is_active is false:
-- Re-run: ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql
```

### **Issue: Mechanic doesn't see popup**
**Solution:**
```sql
-- Check request status
SELECT id, status, shop_id, request_type
FROM service_requests
WHERE status IN ('pending', 'ready_to_assign')
ORDER BY created_at DESC
LIMIT 5;

-- Check if shop_id matches mechanic's shop
-- Shop should be: cedc2e63-7785-4d61-a8f1-9f4ed8d254da
```

---

## 📊 **Deployment Checklist:**

- [ ] **Step 1:** Run `FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql`
- [ ] **Verify:** Test `get_nearby_requests_for_mechanic` works
- [ ] **Step 2:** Run `ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql`
- [ ] **Verify:** Mechanic assigned to shop
- [ ] **Step 3:** Restart Flutter app (`flutter run`)
- [ ] **Test 1:** Customer creates request
- [ ] **Test 2:** Mechanic sees popup
- [ ] **Test 3:** Mechanic accepts request
- [ ] **Verify:** No errors in logs

---

## 🎯 **Expected Final State:**

### **Database:**
```
✅ RLS policies: Relaxed for function access
✅ Shop isolation: Enforced at function level
✅ Mechanic assigned: shop_mechanics table
✅ Get requests function: Working without RLS block
```

### **Flutter App:**
```
✅ Customer: Can create shop-based requests
✅ Mechanic: Sees requests from assigned shop
✅ Mechanic: Can accept requests
✅ Real-time: Updates work correctly
```

### **Logs:**
```
✅ No "Service request not found" errors
✅ No "PGRST116" errors  
✅ No "Shop isolation violation" errors
✅ Acceptance succeeds
```

---

## 📝 **Quick Summary:**

| File | Purpose | Deploy Order | Status |
|------|---------|--------------|--------|
| `FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql` | Fix RLS blocking | 1️⃣ First | 🔴 Deploy Now |
| `ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql` | Assign mechanic | 2️⃣ Second | 🔴 Deploy Now |
| `flutter run` | Restart app | 3️⃣ Third | 🔴 Run Now |

---

## 🚨 **CRITICAL NOTES:**

1. **Run files IN ORDER** - RLS fix must be first
2. **Don't skip verification** - Test queries between steps
3. **Check logs carefully** - Look for ✅ success messages
4. **Restart app after SQL** - Changes need app reload

---

## ✅ **Success Criteria:**

You'll know it's working when:

1. ✅ Mechanic dashboard loads without errors
2. ✅ New request popup appears automatically
3. ✅ Clicking "Accept" succeeds
4. ✅ Request status changes to "assigned"
5. ✅ No error messages in logs

---

**Ready to deploy? Start with Step 1!** 🚀
