# 🏪 Complete Shop Isolation System - Implementation Guide

## 📋 What Was Built

A complete **Angkas-style shop isolation system** where:
- ✅ Customer selects Shop A → ONLY Shop A mechanics see the request
- ✅ Manual acceptance: First mechanic to click "Accept" wins  
- ✅ Decline behavior: Request stays visible to other mechanics
- ✅ Shop isolation enforced at database level

---

## 🚀 Quick Deployment (3 Steps)

### **Step 1: Deploy Database (Supabase SQL Editor)**

Run these SQL files in order:

```sql
-- 1. Complete shop isolation system
-- File: COMPLETE_SHOP_ISOLATION_SYSTEM.sql
-- Creates: RLS policies, accept/decline functions, indexes
```

```sql
-- 2. Update request filtering function
-- File: FIX_SHOP_ISOLATION_COMPLETE.sql
-- Updates: get_nearby_requests_for_mechanic() to filter by shop_id
```

```sql
-- 3. Assign your mechanic to shop
-- File: ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql
-- Assigns: Mechanic (e4cbf14b...) to MechAid supply shop
```

### **Step 2: Verify Database Setup**

```sql
-- Quick verification
SELECT 'RLS Enabled' as check, rowsecurity as value
FROM pg_tables WHERE tablename = 'service_requests'
UNION ALL
SELECT 'Policies Count', COUNT(*)::text
FROM pg_policies WHERE tablename = 'service_requests'
UNION ALL
SELECT 'Mechanic Assigned', COUNT(*)::text
FROM shop_mechanics WHERE mechanic_id IN (
    SELECT id FROM mechanics WHERE user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
);

-- Expected output:
-- RLS Enabled: true
-- Policies Count: 3
-- Mechanic Assigned: 1
```

### **Step 3: Restart Flutter App**

```powershell
flutter run
```

---

## 🧪 Testing (5 Scenarios)

### ✅ Test 1: Shop Visibility
```
1. Customer → Select "MechAid supply"
2. Create request
3. Mechanic A (MechAid supply) → ✅ Sees request
4. Mechanic B (Different shop) → ❌ Does NOT see request
```

### ✅ Test 2: Accept (Same Shop)
```
1. Mechanic A (correct shop) → Click "Accept"
2. Expected: ✅ Success, request assigned
3. Check: status = 'assigned', assigned_mechanic_id set
```

### ✅ Test 3: Accept (Wrong Shop) - SHOULD FAIL
```
1. Mechanic B (wrong shop) → Try to accept
2. Expected: ❌ "Shop isolation violation" error
3. Check: Request stays unassigned
```

### ✅ Test 4: Decline Behavior
```
1. Mechanic A → Click "Decline"
2. Expected: Request disappears for Mechanic A ONLY
3. Check: Mechanic B (same shop) can still see and accept
```

### ✅ Test 5: Race Condition
```
1. Mechanic A & B (same shop) → Click "Accept" simultaneously
2. Expected: Only ONE succeeds
3. Check: Other gets "already accepted" error
```

---

## 🔧 How It Works

### Database Level (RLS Policies)
```sql
-- Mechanics can ONLY see requests where:
-- 1. request.shop_id = mechanic.shop_id
-- 2. mechanic is active in that shop

CREATE POLICY shop_isolation_select_policy
ON service_requests FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM mechanics m
        INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
        WHERE m.user_id = auth.uid()
        AND sm.shop_id = service_requests.shop_id
        AND sm.is_active = true
    )
);
```

### Accept Function (with Shop Validation)
```sql
-- Function: accept_shop_request(request_id, mechanic_user_id)
-- Validates:
-- 1. Mechanic belongs to a shop
-- 2. Request belongs to same shop
-- 3. Request is still available
-- 4. Atomic UPDATE prevents race conditions
```

### Decline Function (Client-Side Only)
```dart
// Decline does NOT update database
// Just hides request locally for that mechanic
Set<String> _declinedRequestIds = {};

void _declineRequest(String requestId) {
  setState(() {
    _declinedRequestIds.add(requestId);
  });
}
```

---

## 🛠️ Troubleshooting

### Mechanic can't see requests
```sql
-- Check assignment
SELECT * FROM shop_mechanics sm
INNER JOIN mechanics m ON m.id = sm.mechanic_id
WHERE m.user_id = 'MECHANIC_USER_ID';

-- If empty, run ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql
```

### "Shop isolation violation" error
```sql
-- Verify shop match
SELECT 
    sr.id as request_id,
    sr.shop_id as request_shop,
    sm.shop_id as mechanic_shop,
    sr.shop_id = sm.shop_id as match
FROM service_requests sr
CROSS JOIN (
    SELECT sm.shop_id
    FROM mechanics m
    INNER JOIN shop_mechanics sm ON sm.mechanic_id = m.id
    WHERE m.user_id = 'MECHANIC_USER_ID'
) sm
WHERE sr.id = 'REQUEST_ID';
```

### Request disappears when declined
```
Problem: Database status changed on decline
Fix: Ensure decline is client-side only, no RPC call
```

---

## 📊 Database Schema

### Key Tables:
```
service_requests
├── id (UUID)
├── customer_id (UUID)
├── shop_id (UUID) ← CRITICAL for isolation
├── assigned_mechanic_id (UUID)
├── status (TEXT)
└── request_type (TEXT)

shop_mechanics (Links mechanics to shops)
├── mechanic_id (UUID)
├── shop_id (UUID) ← Links mechanic to shop
└── is_active (BOOLEAN)

mechanics
├── id (UUID)
└── user_id (UUID) ← auth.users.id
```

---

## ✅ Success Checklist

- [ ] RLS enabled on service_requests
- [ ] 3+ policies created
- [ ] accept_shop_request() function exists
- [ ] Mechanic assigned to shop
- [ ] Test 1: Visibility isolation works
- [ ] Test 2: Accept from correct shop works
- [ ] Test 3: Accept from wrong shop fails
- [ ] Test 4: Decline doesn't affect others
- [ ] Test 5: Race condition handled

---

## 📝 Files Created

1. **COMPLETE_SHOP_ISOLATION_SYSTEM.sql**
   - RLS policies
   - accept_shop_request() function
   - can_decline_request() function
   - Helper functions
   - Performance indexes

2. **FIX_SHOP_ISOLATION_COMPLETE.sql**
   - Updated get_nearby_requests_for_mechanic()
   - Filters by shop_id

3. **ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql**
   - Assigns test mechanic to shop

4. **THIS FILE (ANGKAS_STYLE_SHOP_ISOLATION_GUIDE.md)**
   - Complete deployment guide

---

## 🎯 Next Steps

1. ✅ Run 3 SQL files in Supabase
2. ✅ Restart Flutter app
3. ✅ Test all 5 scenarios
4. ✅ Monitor for errors
5. ✅ Assign more mechanics to shops as needed

---

**Ready to deploy! 🚀**

**Questions?** Check troubleshooting section or review logs for specific errors.
