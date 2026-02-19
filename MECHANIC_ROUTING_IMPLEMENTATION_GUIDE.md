# MECHANIC-FOCUSED ROUTING SYSTEM - IMPLEMENTATION GUIDE

## The Problem You Described ✅
- **Before**: Requests might go to talyer owners, causing confusion
- **Now**: Requests go DIRECTLY to mechanics only
- **Shop-based**: Customer selects shop → only mechanics working in that shop get popup
- **Nearby**: Customer doesn't select shop → all nearby mechanics get popup (like Angkas/Lalamove)

## Database Setup Required 🔧

### 1. Apply the Database Schema First
Run this in your Supabase SQL Editor (or psql):

```bash
# Apply the basic routing table structure first
REQUEST_ROUTING_TABLE_AND_COLUMNS.sql

# Then apply the mechanic-focused fix
MECHANIC_FOCUSED_ROUTING_FIX.sql
```

### 2. Enable Realtime for Real-time Popups
In your Supabase Dashboard:
1. Go to Database → Replication
2. Enable Realtime for the `request_routing` table
3. This allows mechanics to receive instant popups

## How It Works Now 🎯

### Customer Side:
1. **Shop Selected**: Customer picks a specific shop from shop_services_screen.dart
   - Sets `request_type = 'shop_based'`
   - Sets `preferred_shop_id = <shop_id>`
   - Only mechanics working at that shop will see the popup

2. **No Shop Selected**: Customer requests from general service screen
   - Sets `request_type = 'any_available'`
   - `preferred_shop_id = null`
   - All nearby mechanics (within 25km) will see the popup

### Mechanic Side:
1. **Must Go Online**: Mechanic taps "Go Online" in dashboard
   - Updates `mechanic_availability_status` table
   - Sets `is_accepting_requests = true`
   - Captures GPS location for distance calculations

2. **Real-time Listening**: Once online, mechanic listens for popups
   - Stream filters for `eligible_mechanic_id = <mechanic_id>`
   - Only unnotified requests (`is_notified = false`)
   - NO shop owner involvement!

3. **FIFO Acceptance**: First mechanic to accept wins
   - Uses atomic `accept_request_fifo()` function
   - Prevents race conditions
   - Marks request as accepted, others get automatically dismissed

## Key Changes Made 🔄

### Database Schema:
1. **request_routing** table now routes to individual mechanics
2. **shop_mechanics** table links mechanics to shops
3. **mechanic_availability_status** tracks online/offline status
4. **Haversine distance** function calculates nearby mechanics

### App Code:
1. **mechanic_request_service.dart**: Simplified to listen only for mechanic-targeted requests
2. **service_request_service.dart**: Sets proper routing fields when customer creates request
3. **shop_services_screen.dart**: Sets shop-based routing when customer selects specific shop

## Testing Instructions 🧪

### 1. Database Setup
Apply both SQL files to your Supabase project:
- `REQUEST_ROUTING_TABLE_AND_COLUMNS.sql`
- `MECHANIC_FOCUSED_ROUTING_FIX.sql`

### 2. Test Shop-based Routing
1. **Setup**: Ensure mechanics are assigned to shops in `shop_mechanics` table
2. **Mechanic App**: 
   - Login as mechanic
   - Tap "Go Online" (important!)
   - Allow location permission
3. **Customer App**:
   - Select a specific shop
   - Create a service request
4. **Expected**: Only mechanics working at that shop should see popup

### 3. Test Nearby Routing
1. **Mechanic App**: Multiple mechanics go online in different locations
2. **Customer App**: Create request without selecting specific shop
3. **Expected**: All nearby mechanics (within 25km) should see popup

### 4. Test FIFO Acceptance
1. Multiple mechanics should see the same request popup
2. First mechanic to tap "Accept" should get the job
3. Other mechanics should see popup disappear automatically

## Debugging Tips 🔍

### If No Popup Appears:
1. **Check Mechanic Status**: Is mechanic actually online?
   ```sql
   SELECT * FROM mechanic_availability_status WHERE is_accepting_requests = true;
   ```

2. **Check Routing Creation**: Are routing entries being created?
   ```sql
   SELECT * FROM request_routing ORDER BY created_at DESC LIMIT 10;
   ```

3. **Check Distance**: Are mechanics within 25km radius?
   ```sql
   SELECT 
     mas.mechanic_id,
     km_distance(mas.location_latitude, mas.location_longitude, 14.5995, 120.9842) as distance_km
   FROM mechanic_availability_status mas 
   WHERE is_accepting_requests = true;
   ```

4. **Check Realtime**: Is Realtime enabled for `request_routing` table?

### If Multiple Mechanics Accept:
- This should be impossible due to atomic `accept_request_fifo()` function
- Check if the function was applied correctly

## Database Queries for Verification 📊

```sql
-- 1. Check if tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('request_routing', 'shop_mechanics', 'mechanic_availability_status');

-- 2. Check online mechanics
SELECT 
  up.full_name,
  mas.current_status,
  mas.is_accepting_requests,
  mas.shop_id
FROM mechanic_availability_status mas
JOIN user_profiles up ON up.id = mas.mechanic_id
WHERE mas.is_accepting_requests = true;

-- 3. Check recent routing activity
SELECT 
  rr.*,
  sr.status as request_status,
  up.full_name as mechanic_name
FROM request_routing rr
JOIN service_requests sr ON sr.id = rr.request_id
LEFT JOIN user_profiles up ON up.id = rr.eligible_mechanic_id
ORDER BY rr.created_at DESC
LIMIT 10;
```

## Summary ✨
The system now properly routes requests to **mechanics directly**, never to shop owners. When a customer selects a shop, only mechanics working at that shop receive popups. When no shop is selected, all nearby mechanics get the popup, just like Angkas or Lalamove! 🚗💨
