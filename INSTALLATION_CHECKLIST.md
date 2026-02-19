# ⚡ QUICK START: Shop Routing Fix

## ✅ CHECKLIST - I-CHECK MO TO!

### Before Installation:
- [ ] May access sa Supabase dashboard
- [ ] May SQL Editor permissions
- [ ] Naka-backup ang database (optional pero recommended)
- [ ] Alam mo ang Shop IDs para sa testing

### Installation (5 mins):
- [ ] Binuksan ang Supabase SQL Editor
- [ ] Binuksan ang file `FIX_SHOP_SPECIFIC_ROUTING.sql`
- [ ] Nag-copy ng ALL content (Ctrl+A, Ctrl+C)
- [ ] Nag-paste sa SQL Editor (Ctrl+V)
- [ ] Nag-click ng RUN button
- [ ] Nakita ang "Success. No rows returned"
- [ ] Nag-wait 5-10 seconds

### Verification:
- [ ] Run: `SELECT * FROM find_available_mechanics_in_shop('SHOP_ID');`
- [ ] May result (list of mechanics)
- [ ] Run: `SELECT check_shop_mechanic_availability('SHOP_ID');`
- [ ] May JSON result with availability
- [ ] Check trigger: `SELECT trigger_name FROM information_schema.triggers WHERE trigger_name = 'auto_broadcast_new_request';`
- [ ] May 1 row result

### Testing:
- [ ] Customer app: Select Shop B → Create request
- [ ] Verify sa database: `SELECT preferred_shop_id FROM service_requests WHERE id = 'NEW_REQUEST_ID';`
- [ ] Shop B ID dapat ang result
- [ ] Check notified: `SELECT * FROM request_broadcasts WHERE request_id = 'NEW_REQUEST_ID';`
- [ ] Shop B mechanics lang ang naka-list
- [ ] Mechanic app: Shop B mechanic may notification
- [ ] Mechanic app: Shop A mechanic WALANG notification

### Success Indicators:
- [ ] ✅ Shop B mechanics ONLY ang notified kung Shop B selected
- [ ] ✅ May alert kung busy lahat: "All X mechanics are busy"
- [ ] ✅ May alert kung walang mechanics: "No mechanics in shop"
- [ ] ✅ Broadcast works kung walang specific shop
- [ ] ✅ Auto-broadcast on request creation
- [ ] ✅ No duplicates

---

## 🚨 QUICK FIXES

### Wala pang mechanics na lumalabas?
```sql
-- Reset availability
UPDATE mechanic_availability_status
SET current_status = 'available',
    is_accepting_requests = true,
    current_request_id = NULL;
```
- [ ] Run query above
- [ ] Reload customer app
- [ ] Try again

### Trigger not working?
```sql
-- Check trigger
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'auto_broadcast_new_request';
```
- [ ] Kung walang result, run trigger code ulit from SQL file
- [ ] Lines 360-400 sa FIX_SHOP_SPECIFIC_ROUTING.sql

### Wrong shop pa rin?
```sql
-- Check request data
SELECT id, preferred_shop_id, request_type 
FROM service_requests 
WHERE id = 'REQUEST_ID';
```
- [ ] Kung NULL ang preferred_shop_id, customer hindi nag-select ng shop
- [ ] Kung may value, verify Shop ID tama
- [ ] Run manual broadcast: `SELECT broadcast_service_request_with_shop_filter('REQUEST_ID');`

---

## 📱 APP TESTING CHECKLIST

### Customer App:
- [ ] Shop selection screen appears
- [ ] Can select Shop B
- [ ] Create request form complete
- [ ] Submit successful
- [ ] Request appears in "My Requests"
- [ ] Status shows "Finding mechanic..." or similar

### Mechanic App (Shop B):
- [ ] Available requests tab shows request
- [ ] Request details correct
- [ ] Can accept/decline
- [ ] Accept works → Status changes to "Accepted"

### Mechanic App (Shop A):
- [ ] Available requests tab EMPTY
- [ ] Shop B request HINDI lumalabas
- [ ] No notification received

---

## 🎯 QUICK VERIFICATION QUERIES

### 1. Check Shop Mechanics:
```sql
SELECT 
    s.shop_name,
    COUNT(sm.mechanic_id) as total,
    STRING_AGG(up.first_name, ', ') as mechanics
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN user_profiles up ON up.id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;
```
**Expected:** Each shop may list of mechanics

### 2. Check Availability:
```sql
SELECT 
    up.first_name || ' ' || up.last_name as name,
    s.shop_name,
    mas.current_status,
    mas.is_accepting_requests
FROM mechanic_availability_status mas
JOIN user_profiles up ON up.id = mas.mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = mas.mechanic_id
LEFT JOIN shops s ON s.id = sm.shop_id
ORDER BY s.shop_name, up.first_name;
```
**Expected:** Status = 'available', is_accepting_requests = true

### 3. Check Recent Requests:
```sql
SELECT 
    sr.title,
    COALESCE(s.shop_name, 'Broadcast') as shop,
    sr.notified_providers_count,
    sr.status,
    sr.created_at
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
ORDER BY sr.created_at DESC
LIMIT 5;
```
**Expected:** Recent requests with correct shop names

---

## ⏱️ TIME ESTIMATES

| Task | Time |
|------|------|
| Read documentation | 10 mins |
| Install SQL fix | 5 mins |
| Verify installation | 5 mins |
| Test customer app | 5 mins |
| Test mechanic app | 5 mins |
| **TOTAL** | **30 mins** |

---

## 🎉 DONE CHECKLIST

### Installation Complete When:
- [x] SQL file successfully executed
- [x] No errors sa Supabase
- [x] Functions created (3 functions)
- [x] Trigger created (1 trigger)
- [x] Verification queries return results

### Testing Complete When:
- [x] Customer selects Shop B → Only Shop B mechanics notified
- [x] Customer selects Shop A → Only Shop A mechanics notified
- [x] No shop selected → All nearby mechanics notified
- [x] Busy shop shows alert message
- [x] Empty shop shows alert message

### Production Ready When:
- [x] All tests passed
- [x] Monitored for 1 hour
- [x] No errors in logs
- [x] Customer feedback positive
- [x] Mechanic feedback positive

---

## 📋 PRINT THIS PAGE!

Print or bookmark this page for quick reference during installation.

✅ = Tapos na  
⏸️ = In progress  
❌ = Hindi pa ginawa  

---

**GOOD LUCK! Kaya mo yan! 💪🚀**
