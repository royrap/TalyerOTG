Summary: Shop isolation for service requests

This folder contains SQL to enable Row-Level Security (RLS) on `service_requests` and policies to ensure only mechanics from the selected shop can see and accept `shop_based` requests.

What to run:
1) Open the Supabase SQL editor (or psql as an admin) and run `shop_isolation_service_requests.sql`.
2) Verify using the diagnostic queries at the bottom of the script.

Client-side guidance (Supabase JS / Flutter):

Supabase JS (Node / Web) - subscribe to shop-specific requests
```js
// Assume you have the mechanic's shop_id available (e.g., fetched from profile)
const shopId = '...';

const subscription = supabase
  .from(`service_requests:request_type=eq.shop_based,shop_id=eq.${shopId}`)
  .on('INSERT', payload => {
    console.log('New shop-based request for my shop:', payload.new);
    // Show request UI
  })
  .subscribe();

// For broadcast/direct requests (global):
const broadcastSub = supabase
  .from('service_requests:request_type=eq.broadcast')
  .on('INSERT', payload => {
    console.log('Broadcast request:', payload.new);
  })
  .subscribe();
```

Flutter / Dart - local filtering example (supabase_flutter package)
```dart
// Fetch mechanic profile to get shop_id
final userId = supabase.auth.currentUser!.id;
final mechanicProfile = await supabase.from('service_providers').select().eq('user_id', userId).maybeSingle();
final shopId = mechanicProfile?['shop_id'];

// Subscribe to shop-based inserts only for this shop
final shopChannel = supabase.channel('public:service_requests')
  .on(
    RealtimeListenTypes.postgresChanges,
    ChannelFilter(event: 'INSERT', schema: 'public', table: 'service_requests', filter: 'request_type=eq.shop_based AND shop_id=eq.$shopId'),
    (payload, [ref]) {
      // payload contains the inserted row
      final newRequest = payload['new'];
      // display or queue
    }
  )
  .subscribe();

// Local filtering fallback (for safety): when you receive any request, ensure to check the shop_id
void handleIncomingRequest(Map<String, dynamic> request) {
  final reqShopId = request['shop_id'];
  if (request['request_type'] == 'shop_based') {
    if (reqShopId == shopId) {
      // show
    } else {
      // ignore
    }
  } else {
    // handle broadcast/direct per existing rules
  }
}
```

Notes:
- RLS policies use JWT claims: 'jwt.claims.user_id' and 'jwt.claims.role'. Ensure your Supabase auth JWT includes these claims (default `sub` claim is the user UUID). If your JWT uses different claims, update the policy to use `current_setting('jwt.claims.<claim>', true)` accordingly.
- If you use a different table for mechanics (e.g., `mechanics` instead of `shop_mechanics`), update the SQL policies accordingly.
- The UPDATE policy in the SQL script includes a WITH CHECK rule to ensure accepted_by equals the acting mechanic's user_id.

If you'd like, I can also add a trigger to automatically reject shop_based requests (and notify customers) when no active mechanics exist for that shop (to produce the "No available mechanics in this shop right now." message).