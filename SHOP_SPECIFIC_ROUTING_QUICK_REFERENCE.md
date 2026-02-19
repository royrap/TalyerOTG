# 🚀 QUICK FIX: Shop-Specific Routing

## PROBLEMA
Customer pumili ng **Shop B**, pero ang request napunta sa mechanic ng **Shop A**. ❌

## SOLUSYON
Run lang ang SQL file - automatic na gumagana! ✅

---

## 📥 I-INSTALL (5 minutes lang!)

### 1. Buksan ang Supabase
```
Supabase Dashboard → SQL Editor → New Query
```

### 2. Copy-Paste ang Code
```
File: FIX_SHOP_SPECIFIC_ROUTING.sql
Action: Select All (Ctrl+A) → Copy (Ctrl+C) → Paste (Ctrl+V)
```

### 3. Run
```
Click "RUN" button or press F5
Wait 5-10 seconds
Done! ✅
```

---

## ✅ ANO ANG NAGAWA

### Before:
```
Customer → Select Shop B → Request created
    ↓
Shop A Mechanic 1 ← ❌ MALI! (nakita ang request)
Shop A Mechanic 2 ← ❌ MALI! (nakita ang request)
Shop B Mechanic 1
Shop B Mechanic 2
```

### After:
```
Customer → Select Shop B → Request created
    ↓
Shop B Mechanic 1 ← ✅ TAMA! (notified)
Shop B Mechanic 2 ← ✅ TAMA! (notified)
Shop A Mechanic 1   (hindi nakakita)
Shop A Mechanic 2   (hindi nakakita)
```

---

## 🔔 NEW FEATURES

### 1. Shop-Specific Filtering
- ✅ Kung pumili ng Shop B → **Shop B mechanics lang** ang makakakita
- ✅ Kung walang pinili → **Lahat ng nearby** ang makakakita (broadcast mode)

### 2. Availability Alerts
- ✅ **Busy lahat?** → "All 3 mechanics in this shop are currently busy"
- ✅ **Walang mechanics?** → "No mechanics found in the selected shop"

### 3. Smart Routing
- ✅ Auto-check kung available ang mechanic
- ✅ Auto-broadcast on request creation
- ✅ Prevent duplicate notifications

---

## 🧪 QUICK TEST

### Test if working:
```sql
-- 1. Check shop availability
SELECT check_shop_mechanic_availability('YOUR_SHOP_ID');

-- Expected output:
-- {
--   "shop_id": "xxx",
--   "total_mechanics": 3,
--   "available_mechanics": 2,
--   "busy_mechanics": 1,
--   "can_accept_requests": true,
--   "status_message": "2 mechanic(s) available"
-- }

-- 2. See mechanics in shop
SELECT * FROM find_available_mechanics_in_shop('YOUR_SHOP_ID');

-- Expected: List of mechanics with availability status
```

### Real-world test:
1. **Customer app** → Select Shop B → Create request
2. **Check database:**
   ```sql
   SELECT shop_id, notified_providers_count, broadcast_status
   FROM service_requests
   WHERE id = 'NEW_REQUEST_ID';
   ```
3. **Expected:** `shop_id = Shop B ID`, `notified_providers_count > 0`

---

## 🐛 TROUBLESHOOTING

### "Wala paring lumalabas na mechanic"

**Quick Fix:**
```sql
-- Reset mechanic availability
UPDATE mechanic_availability_status
SET current_status = 'available',
    is_accepting_requests = true,
    current_request_id = NULL
WHERE mechanic_id IN (
    SELECT mechanic_id FROM shop_mechanics WHERE shop_id = 'YOUR_SHOP_ID'
);
```

### "Lumalabas pa rin sa wrong shop"

**Check request data:**
```sql
SELECT 
    id, 
    title, 
    preferred_shop_id, 
    shop_id,
    request_type
FROM service_requests 
WHERE id = 'REQUEST_ID'
ORDER BY created_at DESC 
LIMIT 1;
```

**Dapat:**
- `preferred_shop_id` = Selected shop ID
- `request_type` = 'shop_based'

### "Trigger not working"

**Re-create trigger:**
```sql
-- Copy-paste trigger code from FIX_SHOP_SPECIFIC_ROUTING.sql
-- Lines starting with "CREATE TRIGGER auto_broadcast_new_request"
```

---

## 📊 MONITORING

### Dashboard Query:
```sql
SELECT 
    s.shop_name,
    COUNT(sm.mechanic_id) as total,
    COUNT(*) FILTER (
        WHERE mas.current_status = 'available'
    ) as available,
    COUNT(*) FILTER (
        WHERE mas.current_status = 'busy'
    ) as busy
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY available DESC;
```

### Recent Requests:
```sql
SELECT 
    sr.title,
    s.shop_name as selected_shop,
    sr.notified_providers_count as mechanics_notified,
    sr.broadcast_status,
    sr.created_at
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
WHERE sr.created_at > NOW() - INTERVAL '1 hour'
ORDER BY sr.created_at DESC;
```

---

## 🎯 KEY CHANGES

| Aspect | Before | After |
|--------|--------|-------|
| **Routing** | Broadcast to ALL mechanics | Filter by selected shop |
| **Shop B selected** | Shop A mechanics see it ❌ | Only Shop B mechanics ✅ |
| **No mechanics available** | Request hangs ❌ | Alert message ✅ |
| **Duplicate notifications** | Possible ❌ | Prevented ✅ |
| **Busy mechanics** | No feedback ❌ | "X mechanics busy" ✅ |

---

## 📝 FILES CREATED

1. **FIX_SHOP_SPECIFIC_ROUTING.sql** ← Main fix (run this!)
2. **SHOP_SPECIFIC_ROUTING_FIX_TAGALOG.md** ← Detailed guide
3. **SHOP_SPECIFIC_ROUTING_QUICK_REFERENCE.md** ← This file

---

## ✨ ONE-LINE SUMMARY

**Run `FIX_SHOP_SPECIFIC_ROUTING.sql` in Supabase → Shop-specific routing works! 🎉**

---

## 🆘 NEED HELP?

Run diagnostic:
```sql
SELECT 
    'Shops' as table_name, COUNT(*)::text as count FROM shops WHERE is_active = true
UNION ALL
SELECT 'Mechanics', COUNT(*)::text FROM user_profiles WHERE user_type = 'mechanic'
UNION ALL
SELECT 'Available', COUNT(*)::text FROM mechanic_availability_status 
    WHERE current_status = 'available';
```

Expected:
- Shops > 0
- Mechanics > 0  
- Available > 0

Kung ZERO ang available mechanics, i-reset:
```sql
UPDATE mechanic_availability_status
SET current_status = 'available',
    is_accepting_requests = true;
```

---

**Done! Run the SQL file and test. Tapos na! 🚀**
