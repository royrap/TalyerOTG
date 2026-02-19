# 🔧 Pag-aayos ng Shop-Specific Mechanic Routing

## 📋 PROBLEMA

**Sabi mo:** "Diba ang mechanic ko lang na available dalawa pero sa Shop A yun, tapos Shop B pinili ko pero lumabas request ko sa mechanic sa Shop 1"

### Ano ang nangyayari:
1. Customer pumili ng **Shop B**
2. Pero ang request napupunta sa mechanic ng **Shop A** 
3. Hindi tama! Dapat sa **Shop B** lang maghanap ng mechanic ang system

## ✅ SOLUSYON

Ginawa kong **SHOP-SPECIFIC** ang routing system:

### Kung pumili ng specific shop (e.g., Shop B):
- ✅ **ONLY Shop B mechanics** ang makakakita ng request
- ✅ **Hindi makikita** ng Shop A mechanics ang request na to
- ✅ Kung busy lahat sa Shop B, **may alert message** ang customer

### Kung hindi pumili ng specific shop:
- ✅ System mag-**broadcast sa lahat** ng malapit na mechanics (any shop)
- ✅ First-come-first-served basis

## 🚀 PAANO I-INSTALL

### Step 1: Buksan ang Supabase SQL Editor
1. Pumunta sa Supabase Dashboard
2. Click **SQL Editor** sa left sidebar
3. Click **New Query**

### Step 2: I-paste ang SQL Code
1. Buksan ang file: `FIX_SHOP_SPECIFIC_ROUTING.sql`
2. Copy ALL contents (Ctrl+A, Ctrl+C)
3. Paste sa SQL Editor (Ctrl+V)

### Step 3: Run ang Query
1. Click **RUN** button (o press F5)
2. Antayin mag-finish (mga 5-10 seconds)
3. Dapat makita mo: "Success. No rows returned"

### Step 4: Verify kung nag-work
```sql
-- Tingnan kung may available mechanics sa Shop B
SELECT * FROM find_available_mechanics_in_shop('SHOP_B_ID_HERE');

-- Tingnan ang availability status ng shop
SELECT check_shop_mechanic_availability('SHOP_B_ID_HERE');
```

## 📱 ANO ANG NANGYAYARI NGAYON

### Scenario 1: Customer pumili ng Shop B
```
Customer → Selects Shop B → Creates Request
    ↓
System → Searches ONLY in Shop B
    ↓
Found 2 available mechanics in Shop B
    ↓
Notify BOTH mechanics in Shop B
    ↓
First mechanic to accept = Assigned
```

**✅ TAMA NA!** Hindi na makikita ng Shop A mechanics ang request.

### Scenario 2: Lahat ng mechanics sa Shop B ay busy
```
Customer → Selects Shop B → Creates Request
    ↓
System → Searches in Shop B
    ↓
Found 3 mechanics, pero LAHAT BUSY
    ↓
Customer sees alert:
"All 3 mechanics in this shop are currently busy. 
Please wait or select another shop."
```

**✅ MAY ALERT NA!** Hindi na mag-stuck ang request.

### Scenario 3: Walang mechanics sa selected shop
```
Customer → Selects Shop C → Creates Request
    ↓
System → Searches in Shop C
    ↓
Found 0 mechanics
    ↓
Customer sees alert:
"No mechanics found in the selected shop. 
Please try another shop."
```

**✅ CLEAR MESSAGE!** Alam ng customer na walang available.

## 🔍 PAANO MAG-TEST

### Test 1: Shop-Specific Request
1. **Customer App:**
   - Pumili ng Shop B
   - Create service request
   - Submit

2. **Verify:**
   ```sql
   -- Check kung Shop B lang ang notified
   SELECT 
       rb.request_id,
       s.shop_name,
       up.first_name || ' ' || up.last_name as mechanic_name,
       rb.response_status
   FROM request_broadcasts rb
   LEFT JOIN shops s ON s.id = rb.shop_id
   LEFT JOIN user_profiles up ON up.id = rb.mechanic_id
   WHERE rb.request_id = 'YOUR_REQUEST_ID'
   ORDER BY rb.notification_sent_at;
   ```

3. **Expected Result:**
   - Dapat **Shop B mechanics ONLY** ang naka-list
   - Walang Shop A o ibang shop

### Test 2: Busy Shop Alert
1. **Setup:** I-set lahat ng Shop B mechanics to BUSY:
   ```sql
   UPDATE mechanic_availability_status
   SET current_status = 'busy',
       is_accepting_requests = false
   WHERE mechanic_id IN (
       SELECT mechanic_id 
       FROM shop_mechanics 
       WHERE shop_id = 'SHOP_B_ID'
   );
   ```

2. **Customer App:**
   - Pumili ng Shop B
   - Create service request

3. **Expected Result:**
   - Customer dapat makakita ng message:
     > "All X mechanics in this shop are currently busy. Please wait or select another shop."

4. **Cleanup:** I-revert to available:
   ```sql
   UPDATE mechanic_availability_status
   SET current_status = 'available',
       is_accepting_requests = true
   WHERE mechanic_id IN (
       SELECT mechanic_id 
       FROM shop_mechanics 
       WHERE shop_id = 'SHOP_B_ID'
   );
   ```

### Test 3: Broadcast Mode (No Shop Selected)
1. **Customer App:**
   - **HUWAG** pumili ng specific shop
   - Create service request

2. **Expected Result:**
   - Lahat ng nearby mechanics (from any shop) makakakita
   - First to accept wins

## 📊 MONITORING QUERIES

### 1. Tingnan ang Shop Availability
```sql
SELECT 
    s.id,
    s.shop_name,
    COUNT(sm.mechanic_id) as total_mechanics,
    COUNT(*) FILTER (
        WHERE mas.current_status = 'available' 
        AND mas.is_accepting_requests = true
    ) as available_mechanics,
    COUNT(*) FILTER (
        WHERE mas.current_status = 'busy'
    ) as busy_mechanics
FROM shops s
LEFT JOIN shop_mechanics sm ON sm.shop_id = s.id AND sm.is_active = true
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = sm.mechanic_id
WHERE s.is_active = true
GROUP BY s.id, s.shop_name
ORDER BY s.shop_name;
```

### 2. Check Recent Broadcasts
```sql
SELECT 
    sr.id as request_id,
    sr.title,
    COALESCE(s.shop_name, 'Broadcast (No Specific Shop)') as target_shop,
    sr.broadcast_status,
    sr.notified_providers_count,
    sr.created_at
FROM service_requests sr
LEFT JOIN shops s ON s.id = sr.preferred_shop_id
WHERE sr.created_at > NOW() - INTERVAL '1 hour'
ORDER BY sr.created_at DESC;
```

### 3. Tingnan kung sino ang notified per request
```sql
SELECT 
    sr.title as request_title,
    COALESCE(s.shop_name, 'Independent') as mechanic_shop,
    up.first_name || ' ' || up.last_name as mechanic_name,
    mas.current_status as mechanic_status,
    rb.response_status,
    rb.notification_sent_at
FROM request_broadcasts rb
JOIN service_requests sr ON sr.id = rb.request_id
LEFT JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = rb.mechanic_id
LEFT JOIN shops s ON s.id = sm.shop_id
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = rb.mechanic_id
WHERE sr.id = 'YOUR_REQUEST_ID'
ORDER BY rb.notification_sent_at;
```

## 🐛 TROUBLESHOOTING

### Problem: Wala paring lumalabas na mechanics kahit may available
**Solution:**
```sql
-- Check mechanic availability status
SELECT 
    up.id,
    up.first_name || ' ' || up.last_name as name,
    mas.current_status,
    mas.is_accepting_requests,
    mas.current_request_id,
    sm.shop_id,
    s.shop_name
FROM user_profiles up
LEFT JOIN mechanic_availability_status mas ON mas.mechanic_id = up.id
LEFT JOIN shop_mechanics sm ON sm.mechanic_id = up.id
LEFT JOIN shops s ON s.id = sm.shop_id
WHERE up.user_type = 'mechanic'
  AND up.status = 'active'
ORDER BY s.shop_name, up.first_name;
```

Dapat:
- `current_status = 'available'`
- `is_accepting_requests = true`
- `current_request_id = NULL`

Kung hindi:
```sql
-- I-reset ang availability
UPDATE mechanic_availability_status
SET current_status = 'available',
    is_accepting_requests = true,
    current_request_id = NULL
WHERE mechanic_id = 'MECHANIC_ID_HERE';
```

### Problem: Lumalabas pa rin sa ibang shop
**Check kung tama ang preferred_shop_id:**
```sql
SELECT 
    id,
    title,
    preferred_shop_id,
    shop_id,
    request_type,
    broadcast_status
FROM service_requests
WHERE id = 'REQUEST_ID_HERE';
```

Dapat:
- `preferred_shop_id` = Shop ID na pinili ng customer
- `request_type` = 'shop_based' (if may pinili) o 'broadcast' (if wala)

### Problem: Trigger hindi gumagana
**I-check ang trigger:**
```sql
-- Tingnan kung naka-enable ang trigger
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'auto_broadcast_new_request';
```

Kung wala, i-recreate:
```sql
-- Run ulit ang trigger creation code from FIX_SHOP_SPECIFIC_ROUTING.sql
```

## 📞 SUPPORT

Kung may problema pa rin:

1. **Check logs sa Supabase:**
   - Go to Dashboard > Logs > Postgres Logs
   - Hanapin ang error messages

2. **Run diagnostic queries:**
   ```sql
   -- Full system diagnostic
   SELECT 'Total Shops' as metric, COUNT(*)::text as value FROM shops WHERE is_active = true
   UNION ALL
   SELECT 'Total Mechanics', COUNT(*)::text FROM user_profiles WHERE user_type = 'mechanic'
   UNION ALL
   SELECT 'Available Mechanics', COUNT(*)::text FROM mechanic_availability_status 
       WHERE current_status = 'available' AND is_accepting_requests = true
   UNION ALL
   SELECT 'Pending Requests', COUNT(*)::text FROM service_requests WHERE status = 'pending';
   ```

3. **Screenshots na i-send:**
   - Customer app - Shop selection screen
   - Mechanic app - Available requests screen
   - Supabase - Query results

## ✨ SUMMARY

### Before Fix:
❌ Customer pumili ng Shop B → Napunta sa Shop A mechanics
❌ Walang alert kung busy lahat
❌ Walang filter based on selected shop

### After Fix:
✅ Customer pumili ng Shop B → **ONLY Shop B mechanics** notified
✅ May **clear alert** kung busy lahat: "All X mechanics are busy"
✅ May **fallback message** kung walang mechanics: "No mechanics in shop"
✅ **Broadcast mode** works kung walang specific shop selected
✅ **Auto-routing** with trigger on request creation

---

**Tapos na ang fix! I-run mo lang ang SQL file at automatic na gumagana.**

Kung may tanong pa, message mo lang ako! 👍
