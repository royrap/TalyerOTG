# Database Functions Deployment Guide

## Problem
The location-based request system requires PostgreSQL functions that are not deployed yet:
- `get_nearby_requests_for_mechanic()`
- `accept_nearby_request()`

## Error Message
```
ERROR: 42883: function get_nearby_requests_for_mechanic(uuid, numeric, numeric, numeric) does not exist
```

## Solution Steps

### Step 1: Deploy Database Functions

You need to execute the `LOCATION_BASED_REQUEST_FUNCTIONS.sql` file on your production database.

#### Option A: Through Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to "SQL Editor"
3. Create a new query
4. Copy and paste the entire content of `LOCATION_BASED_REQUEST_FUNCTIONS.sql`
5. Execute the query

#### Option B: Through psql command line
```bash
# Connect to your database
psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"

# Execute the functions file
\i LOCATION_BASED_REQUEST_FUNCTIONS.sql
```

#### Option C: Through Supabase CLI (when Docker is available)
```bash
# Start local development
supabase start

# Apply migrations
supabase db push

# Or execute directly
supabase db reset
```

### Step 2: Verify Functions Are Deployed

Run this query to check if functions exist:
```sql
SELECT 
    proname as function_name,
    'Function exists' as status
FROM pg_proc 
WHERE proname IN ('get_nearby_requests_for_mechanic', 'accept_nearby_request');
```

Should return:
```
function_name                     | status
get_nearby_requests_for_mechanic | Function exists
accept_nearby_request           | Function exists
```

### Step 3: Test the Location-Based System

After deploying the functions, run the updated `test_location_based_system.sql` script.

## Alternative: Manual Testing Without Functions

If you can't deploy the functions immediately, the updated test script includes a manual distance calculation that simulates the function behavior using pure SQL.

## Functions Overview

### `get_nearby_requests_for_mechanic()`
- **Purpose**: Find service requests near a mechanic's location
- **Parameters**: mechanic_id, latitude, longitude, max_distance_km
- **Returns**: List of nearby requests with distance and eligibility info

### `accept_nearby_request()`
- **Purpose**: Accept a request with location validation
- **Parameters**: mechanic_id, request_id, mechanic_lat, mechanic_lng
- **Returns**: Success status, message, and distance

## Required for Location-Based Features

These functions are essential for:
- Mechanics to see nearby requests
- Distance-based filtering and sorting
- Request acceptance validation
- Performance optimization (server-side calculations)

## Next Steps

1. **Deploy the functions** using one of the methods above
2. **Run the test script** to verify everything works
3. **Test in the mobile app** by going to Dashboard → Nearby Requests
4. **Monitor logs** for any remaining issues

The location-based request system will work properly once these database functions are deployed!