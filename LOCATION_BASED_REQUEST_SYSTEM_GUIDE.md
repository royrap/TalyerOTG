# Location-Based Request System - Filipino

## Pagkilala (Overview)

Ang system na ito ay nagpapakita ng service requests sa mga mechanics base sa **pickup location** (pickup_latitude, pickup_longitude) ng customer. Kapag malapit ang mechanic sa pickup location, makikita niya ang request.

## Paano Gumagana (How It Works)

### 1. Customer Creates Request
```
Customer → Service Type Selection → Vehicle Details → Service Request
```
- Customer nagse-set ng **pickup location** (kung saan siya nandoon)
- Coordinates na-save sa `pickup_latitude` at `pickup_longitude`
- Address na-save sa `pickup_address`

### 2. Mechanic Sees Nearby Requests
```
Mechanic → Location Permission → Nearby Requests Dashboard
```
- System kumukunha ng current location ng mechanic
- Ginagamit ang **Haversine formula** para sa distance calculation
- Pinapakita lang ang requests na malapit (default: 50km radius)

### 3. Distance Calculation
```sql
-- Haversine Formula (Database Function)
6371 * acos(
    cos(radians(mechanic_lat)) * 
    cos(radians(pickup_latitude)) * 
    cos(radians(pickup_longitude) - radians(mechanic_lng)) + 
    sin(radians(mechanic_lat)) * 
    sin(radians(pickup_latitude))
) AS distance_km
```

## Database Schema

### Service Requests Table Key Fields:
```sql
pickup_latitude NUMERIC(10, 8) NOT NULL,    -- Customer location lat
pickup_longitude NUMERIC(11, 8) NOT NULL,   -- Customer location lng  
pickup_address TEXT,                        -- Human readable address
distance_to_customer NUMERIC,              -- Distance when accepted
estimated_arrival_minutes INTEGER,         -- ETA calculation
```

### Location Indexes:
```sql
-- For fast location queries
CREATE INDEX idx_service_requests_location 
ON service_requests(pickup_latitude, pickup_longitude);

-- For location + status filtering  
CREATE INDEX idx_service_requests_location_status 
ON service_requests(pickup_latitude, pickup_longitude, status) 
WHERE status IN ('pending', 'awaiting_payment', 'ready_to_assign');
```

## Mga Features (Features)

### 📍 Location-Based Filtering
- **Distance Calculation**: Exact distance from mechanic to pickup point
- **Radius Control**: Mechanics can set max distance (5km - 100km)
- **Real-time Updates**: Updates every 30 seconds

### 🎯 Smart Eligibility
- **Direct Requests**: Available to ALL nearby mechanics
- **Shop Requests**: Only for mechanics working at that specific shop
- **Availability Check**: Only shows to mechanics who are accepting requests

### ⚡ Performance Optimized
- **Database Functions**: Server-side calculation for better performance
- **Indexed Queries**: Fast location-based searches
- **Fallback Methods**: Graceful degradation if optimized functions fail

### 🚨 Priority System
- **High Priority**: Requests waiting 2+ hours
- **Medium Priority**: Requests waiting 1+ hours  
- **Normal Priority**: New requests

## Code Structure

### 1. LocationBasedRequestService
```dart
// Main service for location-based requests
class LocationBasedRequestService {
  // Get nearby requests
  static Future<List<Map<String, dynamic>>> getRequestsNearMechanic()
  
  // Accept nearby request
  static Future<bool> acceptNearbyRequest()
  
  // Calculate distance between two points
  static double _calculateDistance()
}
```

### 2. MechanicLocationBasedDashboard
```dart
// UI screen for mechanics to see nearby requests
class MechanicLocationBasedDashboard extends StatefulWidget {
  // Real-time location tracking
  // Request cards with distance info
  // Accept request functionality
}
```

### 3. Database Functions
```sql
-- Optimized server-side functions
get_nearby_requests_for_mechanic()  -- Get eligible nearby requests
accept_nearby_request()             -- Accept with validation
```

## Workflow Examples

### Para sa Direct Mechanic Request:
1. Customer: "Need help sa EDSA Cubao"
2. System: Saves `pickup_latitude: 14.6198`, `pickup_longitude: 121.0568`
3. Mechanic sa Quezon City (5km away): Makakakita ng request
4. Mechanic sa Cavite (30km away): Makakakita rin (within 50km default)
5. Mechanic accepts → System calculates exact distance and ETA

### Para sa Shop-Based Request:
1. Customer: "Need service sa Shell Station EDSA"
2. System: Saves pickup location + `preferred_shop_id`
3. Only mechanics from that specific shop: Makakakita ng request
4. Other mechanics: Hindi makakakita even if malapit sila

## Database Triggers

### Auto Distance Calculation:
```sql
-- When request is accepted, auto-calculate distance
UPDATE service_requests 
SET 
  distance_to_customer = calculated_distance,
  estimated_arrival_minutes = (distance / 30 * 60) + 5
WHERE id = request_id;
```

### Mechanic Status Update:
```sql
-- Auto-update mechanic availability when accepting request
UPDATE mechanic_availability_status 
SET 
  current_status = 'on_job',
  is_accepting_requests = false
WHERE mechanic_id = accepting_mechanic;
```

## API Endpoints (Supabase RPC)

### Get Nearby Requests:
```dart
final result = await supabase.rpc('get_nearby_requests_for_mechanic', params: {
  'p_mechanic_id': mechanicId,
  'p_mechanic_lat': 14.6198,      // Mechanic current latitude
  'p_mechanic_lng': 121.0568,     // Mechanic current longitude  
  'p_max_distance_km': 50.0,      // Search radius
});
```

### Accept Request:
```dart
final result = await supabase.rpc('accept_nearby_request', params: {
  'p_mechanic_id': mechanicId,
  'p_request_id': requestId,
  'p_mechanic_lat': mechanicLat,
  'p_mechanic_lng': mechanicLng,
});
```

## UI Components

### Request Card Information:
- **Customer Info**: Name, phone, profile picture
- **Service Details**: Title, description, service type
- **Location**: Pickup address, distance from mechanic
- **Timing**: ETA, urgency level, how long waiting
- **Priority**: Visual indicators (red=urgent, orange=medium, green=normal)

### Distance Display:
- `< 1km`: "500m away"
- `1-10km`: "5.2km away"
- `> 10km`: "25km away"

### ETA Calculation:
```dart
// Assume 30 km/h average city speed + 5 minutes preparation
int estimatedMinutes = ((distance / 30.0) * 60).round() + 5;
```

## Testing Scenarios

### 1. Urban Area (Metro Manila):
- Dense request concentration
- Short distances (1-10km)
- High competition among mechanics

### 2. Provincial Area:
- Scattered requests
- Longer distances (20-50km)
- Fewer available mechanics

### 3. Shop-based vs Direct:
- Shop mechanics only see shop requests + direct requests
- Independent mechanics only see direct requests

## Performance Considerations

### Database Optimization:
- Location indexes for fast spatial queries
- Composite indexes for multi-field filtering
- Server-side distance calculation to reduce client processing

### Real-time Updates:
- 30-second refresh interval
- Pull-to-refresh functionality
- Automatic location updates when mechanic moves

### Error Handling:
- Graceful fallback to client-side calculation
- Location permission handling
- Network connectivity checks

## Configuration

### Default Settings:
```dart
double defaultMaxDistance = 50.0;        // 50km search radius
int refreshInterval = 30;                // 30 seconds
double averageSpeed = 30.0;              // 30 km/h for ETA
int preparationTime = 5;                 // 5 minutes prep time
```

### Distance Limits:
- Minimum: 5km (very local)
- Maximum: 100km (wide area coverage)
- Default: 50km (balanced)

Ang system na ito ay nag-ensure na ang mga mechanics ay makakakita lang ng mga requests na praktical nilang ma-serve base sa kanilang location, at ang mga customers ay makakatanggap ng service from the nearest available mechanics.