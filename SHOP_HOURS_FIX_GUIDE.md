# 🔧 PAANO AYUSIN ANG SHOP HOURS ISSUES

## ❌ Dalawang Problema

### 1. **Nakikita pa rin ni Customer ang Closed Shops**
- Kahit sarado na ang shop, lumalabas pa rin sa list
- Hindi gumagana ang time filter

### 2. **Military Time Format (24-hour)**
- Nakikita ng Talyer Owner: "18:00" 
- Dapat: "6:00 PM"

---

## 🔍 STEP 1: I-debug Kung Bakit Lumalabas pa rin ang Closed Shops

### Run mo ito sa Supabase SQL Editor:

```sql
-- File: DEBUG_SHOP_HOURS_ISSUE.sql
```

Makikita mo dito:
- Current time at day
- Business hours ng bawat shop
- Kung open o closed dapat ang shop ngayon
- Kung gumagana ba talaga ang `is_shop_open()` function

---

## ✅ STEP 2: Ayusin ang Closed Shop Filter

### Posibleng mga dahilan:

#### **Dahilan 1: Wrong Format ng business_hours**

Check mo kung ganito format sa database:
```json
{
  "monday": {"open": "08:00", "close": "18:00"},
  "tuesday": {"open": "08:00", "close": "18:00"},
  "sunday": {"open": null, "close": null}
}
```

**MALI kung:**
```json
{
  "monday": {"open": "8:00 AM", "close": "6:00 PM"}  ❌ Wrong!
}
```

**TAMA kung:**
```json
{
  "monday": {"open": "08:00", "close": "18:00"}  ✅ Correct!
}
```

#### **Dahilan 2: Flutter App May Cache**

Baka naka-cache pa yung old data sa Flutter app.

**Fix:**
```dart
// In Flutter, add this to clear cache
final nearbyShopsResponse = await SupabaseService.client
    .rpc('get_nearby_shops', params: {
      'customer_lat': currentLocation.latitude,
      'customer_lon': currentLocation.longitude,
      'radius_km': 15.0,
    })
    .select()
    .eq('is_open', true);  // Force filter
```

#### **Dahilan 3: Hindi Updated ang Function**

I-check mo kung naka-install na ba yung `HIDE_CLOSED_SHOPS_IMPLEMENTATION.sql`

**Test kung installed:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'is_shop_open';
```

Kung walang result, i-run mo ulit ang `HIDE_CLOSED_SHOPS_IMPLEMENTATION.sql`

#### **Dahilan 4: Wrong Timezone**

Baka naka-set sa wrong timezone ang server.

**Check timezone:**
```sql
SHOW timezone;  -- Should be 'Asia/Manila'
```

**Set to Philippine time:**
```sql
SET timezone = 'Asia/Manila';
```

---

## 🕐 STEP 3: Ayusin ang Military Time (24-hour → 12-hour)

### Run mo ito sa Supabase SQL Editor:

```sql
-- File: FIX_MILITARY_TIME_TO_12HOUR_FORMAT.sql
```

Ito ay mag-create ng 3 functions:
1. `format_time_12hour('18:00')` → Returns `'6:00 PM'`
2. `get_formatted_business_hours(business_hours_jsonb)` → Converts all times
3. `get_nearby_shops_with_formatted_hours()` → Returns shops with formatted times

---

## 📱 STEP 4: I-update ang Flutter App

### Option A: Use New RPC with Formatted Hours

```dart
// In lib/services/supabase_service.dart or wherever you call RPC

Future<List<Shop>> getNearbyShopsWithFormattedHours({
  required double latitude,
  required double longitude,
  double radiusKm = 15.0,
}) async {
  try {
    final response = await client
        .rpc('get_nearby_shops_with_formatted_hours', params: {
          'customer_lat': latitude,
          'customer_lon': longitude,
          'radius_km': radiusKm,
        });

    return (response as List).map((shop) {
      return Shop(
        id: shop['shop_id'],
        name: shop['shop_name'],
        address: shop['shop_address'],
        // Get formatted hours (12-hour format)
        formattedHours: shop['formatted_hours'],
        // Raw hours (24-hour format) - still available if needed
        businessHours: shop['business_hours'],
        isOpen: shop['is_open'],
        distance: shop['distance_km'],
      );
    }).toList();
  } catch (e) {
    print('Error fetching nearby shops: $e');
    return [];
  }
}
```

### Option B: Format in Flutter (Client-Side)

```dart
// Create a utility function in Flutter
String format12Hour(String militaryTime) {
  if (militaryTime == null || militaryTime.isEmpty || militaryTime == 'closed') {
    return 'Closed';
  }
  
  try {
    final parts = militaryTime.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    
    String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour > 12) {
      hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }
    
    return '$hour:$minute $period';
  } catch (e) {
    return militaryTime;
  }
}

// Usage in UI
Text(
  'Open: ${format12Hour(shop.businessHours['monday']['open'])}',
)
```

---

## 🎯 STEP 5: Test ng Maigi

### Test 1: Check Closed Shop Filter

```sql
-- Should return only OPEN shops
SELECT 
    shop_name,
    is_shop_open(business_hours, NOW()) as is_open
FROM shops
WHERE is_active = true;
```

### Test 2: Check Time Format

```sql
-- Should return "6:00 PM" not "18:00"
SELECT format_time_12hour('18:00');
```

### Test 3: Check Full Business Hours

```sql
SELECT 
    shop_name,
    business_hours as raw_hours,
    get_formatted_business_hours(business_hours) as formatted_hours
FROM shops
LIMIT 1;
```

---

## 📋 CHECKLIST: Sundin mo ito

- [ ] **Step 1:** Run `DEBUG_SHOP_HOURS_ISSUE.sql` para makita kung ano problema
- [ ] **Step 2:** Verify business_hours format sa database (dapat 24-hour: "08:00", "18:00")
- [ ] **Step 3:** Confirm na installed na ang `is_shop_open()` function
- [ ] **Step 4:** Run `FIX_MILITARY_TIME_TO_12HOUR_FORMAT.sql` para sa 12-hour format
- [ ] **Step 5:** Update Flutter app to use `get_nearby_shops_with_formatted_hours()`
- [ ] **Step 6:** Test sa customer app - dapat di na makita ang closed shops
- [ ] **Step 7:** Test sa talyer owner app - dapat 12-hour format na (6:00 PM)

---

## 🚨 Common Issues at Solutions

### Issue 1: "Function is_shop_open does not exist"
**Solution:** Run `HIDE_CLOSED_SHOPS_IMPLEMENTATION.sql` ulit

### Issue 2: "All shops showing as closed"
**Solution:** Check kung tama ang format ng business_hours sa database

### Issue 3: "Still seeing military time"
**Solution:** 
- Run `FIX_MILITARY_TIME_TO_12HOUR_FORMAT.sql`
- Update Flutter to use `format_time_12hour()` or format client-side

### Issue 4: "Closed shops still appearing"
**Solution:**
- Clear Flutter app cache
- Force reload data
- Check timezone settings
- Verify `get_nearby_shops()` is using latest version

---

## 💡 Pro Tips

1. **Para sa Talyer Owner UI:**
   - Display both formats: "6:00 PM (18:00)" para clear
   - When saving, always save in 24-hour format (18:00)
   - When displaying, convert to 12-hour format (6:00 PM)

2. **Para sa Customer UI:**
   - Only show "Open Now" shops
   - Display shop hours in 12-hour format
   - Show "Opens at 8:00 AM" kung sarado

3. **Para sa Database:**
   - Always store in 24-hour format (easier for comparison)
   - Use `is_shop_open()` function for filtering
   - Use `format_time_12hour()` for display

---

## 📞 Kung May Mali Pa Rin

1. Run `DEBUG_SHOP_HOURS_ISSUE.sql`
2. Copy paste mo sakin yung output
3. Copy paste mo din yung current `business_hours` ng isang shop
4. Tell me kung anong oras na sa Pilipinas ngayon
5. Tell me kung ano nakikita ni customer (screenshot if possible)

---

**Created:** October 9, 2025  
**For:** RoadAid Auto Repair System  
**Issue:** Closed shops still showing + Military time format
