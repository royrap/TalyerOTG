# 🎨 Shop Routing Fix - Visual Flow Diagram

## CURRENT PROBLEM (BEFORE FIX)

```
┌─────────────────────────────────────────────────────────────┐
│                    CUSTOMER APP                             │
│                                                             │
│  Customer selects:  [Shop B] ← Selected Shop B             │
│  Service type:      [Tire Change]                          │
│                                                             │
│                   [Submit Request] ← Click                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  DATABASE PROCESSING                        │
│                                                             │
│  Request Created:                                           │
│  - preferred_shop_id: Shop B ID ✓                          │
│  - customer_location: (14.123, 121.456)                    │
│  - status: pending                                          │
│                                                             │
│  ❌ BUG: broadcast_service_request() ignores shop_id       │
│                                                             │
│  Searching for mechanics:                                   │
│  WHERE current_status = 'available'                         │
│  AND distance < 25km                                        │
│  ❌ NO FILTER: preferred_shop_id                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌──────────────────┐            ┌──────────────────┐
│   SHOP A         │            │   SHOP B         │
│   (WRONG!)       │            │   (CORRECT)      │
│                  │            │                  │
│ ❌ Mechanic 1    │            │ ✅ Mechanic 1    │
│    NOTIFIED      │            │    NOTIFIED      │
│                  │            │                  │
│ ❌ Mechanic 2    │            │ ✅ Mechanic 2    │
│    NOTIFIED      │            │    NOTIFIED      │
└──────────────────┘            └──────────────────┘

RESULT: Shop A mechanics see Shop B's request ❌
```

---

## SOLUTION (AFTER FIX)

```
┌─────────────────────────────────────────────────────────────┐
│                    CUSTOMER APP                             │
│                                                             │
│  Customer selects:  [Shop B] ← Selected Shop B             │
│  Service type:      [Tire Change]                          │
│                                                             │
│                   [Submit Request] ← Click                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│            DATABASE PROCESSING (FIXED!)                     │
│                                                             │
│  Request Created:                                           │
│  - preferred_shop_id: Shop B ID ✓                          │
│  - customer_location: (14.123, 121.456)                    │
│  - status: pending                                          │
│                                                             │
│  ✅ NEW: broadcast_service_request_with_shop_filter()      │
│                                                             │
│  IF preferred_shop_id IS NOT NULL:                         │
│    ✅ Search ONLY in Shop B                                │
│    ✅ Filter: shop_mechanics.shop_id = Shop B              │
│    ✅ Check: current_status = 'available'                  │
│                                                             │
│  Searching for mechanics:                                   │
│  FROM mechanic_availability_status mas                      │
│  JOIN shop_mechanics sm ON sm.mechanic_id = mas.mechanic_id│
│  ✅ WHERE sm.shop_id = 'Shop B'                            │
│  AND mas.current_status = 'available'                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ ✅ FILTERED!
                        ▼
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌──────────────────┐            ┌──────────────────┐
│   SHOP A         │            │   SHOP B         │
│   (FILTERED)     │            │   (TARGET)       │
│                  │            │                  │
│   Mechanic 1     │            │ ✅ Mechanic 1    │
│   (no notification)│          │    NOTIFIED ✓    │
│                  │            │                  │
│   Mechanic 2     │            │ ✅ Mechanic 2    │
│   (no notification)│          │    NOTIFIED ✓    │
└──────────────────┘            └──────────────────┘

RESULT: Only Shop B mechanics notified ✅
```

---

## FLOW CHART: Request Processing

```
                    START
                      │
                      ▼
        ┌─────────────────────────┐
        │   Customer Creates      │
        │   Service Request       │
        └──────────┬──────────────┘
                   │
                   ▼
        ┌─────────────────────────┐
        │  Did customer select    │
        │  a specific shop?       │
        └──┬───────────────────┬──┘
           │ YES               │ NO
           │                   │
           ▼                   ▼
┌──────────────────────┐  ┌────────────────────────┐
│  SHOP-BASED MODE     │  │  BROADCAST MODE        │
│                      │  │                        │
│ Get preferred_shop_id│  │ Search ALL nearby      │
│       ↓              │  │ mechanics within       │
│ Query mechanics:     │  │ radius (25km default)  │
│                      │  │        ↓               │
│ FROM shop_mechanics  │  │ Any shop, any mechanic │
│ WHERE shop_id =      │  │ First-come-first-serve │
│   preferred_shop_id  │  └────────┬───────────────┘
│       ↓              │           │
│ Check availability:  │           │
│ - status = available │           │
│ - accepting_requests │           │
│       ↓              │           │
│ Found mechanics?     │           │
└──┬───────────────┬───┘           │
   │ YES           │ NO            │
   │               │               │
   ▼               ▼               ▼
┌─────────┐  ┌──────────────┐  ┌─────────────┐
│ Notify  │  │ Show Alert:  │  │ Notify All  │
│ Shop B  │  │              │  │ Available   │
│ Mechanics│  │ "All X      │  │ Mechanics   │
│         │  │  mechanics   │  │             │
│ Create  │  │  are busy"   │  │ Create      │
│ routing │  │              │  │ routing     │
│ entries │  │ OR           │  │ entries     │
│         │  │              │  │             │
│ Send    │  │ "No mechanics│  │ Send        │
│ push    │  │  in shop"    │  │ broadcasts  │
│ notifs  │  │              │  │             │
└────┬────┘  └──────────────┘  └──────┬──────┘
     │                                │
     └────────────┬───────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │  Wait for mechanic  │
        │  to accept          │
        │  (FIFO basis)       │
        └──────────┬──────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │  First mechanic     │
        │  accepts = Assigned │
        └──────────┬──────────┘
                   │
                   ▼
                  END
```

---

## SCENARIO COMPARISON

### Scenario 1: 2 Available Mechanics in Shop B

**BEFORE FIX:**
```
Customer selects Shop B
    ↓
System searches everywhere
    ↓
Notified:
├─ Shop A Mechanic 1 ❌
├─ Shop A Mechanic 2 ❌  
├─ Shop B Mechanic 1 ✓
├─ Shop B Mechanic 2 ✓
└─ Shop C Mechanic 1 ❌

Result: 5 mechanics notified (3 wrong shop!)
```

**AFTER FIX:**
```
Customer selects Shop B
    ↓
System searches ONLY in Shop B
    ↓
Notified:
├─ Shop B Mechanic 1 ✓
└─ Shop B Mechanic 2 ✓

Result: 2 mechanics notified (correct shop!)
```

### Scenario 2: All Shop B Mechanics Busy

**BEFORE FIX:**
```
Customer selects Shop B
    ↓
All Shop B mechanics busy
    ↓
Request just stays "pending"
    ↓
❌ No feedback to customer
    ↓
Customer confused, waits forever
```

**AFTER FIX:**
```
Customer selects Shop B
    ↓
System checks Shop B mechanics
    ↓
Found: 3 total, 0 available, 3 busy
    ↓
✅ Alert shown to customer:
"All 3 mechanics in this shop are currently busy.
 Please wait or select another shop."
    ↓
Customer can:
- Wait for availability
- Select different shop
- Cancel request
```

### Scenario 3: Empty Shop (No Mechanics)

**BEFORE FIX:**
```
Customer selects Shop C (new shop, no mechanics yet)
    ↓
Request created
    ↓
❌ Broadcast to other shops (wrong!)
    ↓
Shop A/B mechanics see Shop C's request
```

**AFTER FIX:**
```
Customer selects Shop C (no mechanics)
    ↓
System checks Shop C
    ↓
Found: 0 mechanics
    ↓
✅ Alert shown immediately:
"No mechanics found in the selected shop.
 Please try another shop."
    ↓
Request status: pending
broadcast_status: no_mechanics_available
```

---

## DATABASE FLOW

### Old Function Flow:
```sql
broadcast_service_request(request_id)
    │
    ├─ Get request details
    │  (ignores preferred_shop_id ❌)
    │
    ├─ Find mechanics:
    │  WHERE status = 'available'
    │  AND distance < 25km
    │  (no shop filter ❌)
    │
    └─ Notify ALL found mechanics
       (wrong shops included ❌)
```

### New Function Flow:
```sql
broadcast_service_request_with_shop_filter(request_id)
    │
    ├─ Get request details
    │  ✅ Check preferred_shop_id
    │
    ├─ IF shop_id IS NOT NULL:
    │  │
    │  ├─ Find mechanics:
    │  │  FROM shop_mechanics
    │  │  ✅ WHERE shop_id = preferred_shop_id
    │  │  AND status = 'available'
    │  │
    │  ├─ Count results:
    │  │  total_mechanics = 3
    │  │  available_mechanics = 2
    │  │
    │  └─ IF available > 0:
    │     │  ✅ Notify available mechanics
    │     │  ✅ Create routing entries
    │     │  ✅ Return success
    │     ELSE:
    │        ✅ Return "all busy" message
    │
    └─ ELSE (no shop selected):
       │
       ├─ Broadcast mode
       └─ Search all nearby mechanics
```

---

## NOTIFICATION TARGETS

### Case 1: Shop B Selected (Shop-Based Request)

```
┌──────────────────────────────────────────────────────────┐
│                    REQUEST DATA                          │
├──────────────────────────────────────────────────────────┤
│  id: req-123                                             │
│  preferred_shop_id: shop-b-id ← KEY FIELD               │
│  request_type: 'shop_based'                              │
│  status: 'pending'                                       │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   FILTER MECHANICS    │
              │                       │
              │  shop_mechanics       │
              │  WHERE shop_id =      │
              │    'shop-b-id'        │
              └───────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
    ┌──────────────┐            ┌──────────────┐
    │  Mechanic 1  │            │  Mechanic 2  │
    │  Shop B      │            │  Shop B      │
    │  Available ✓ │            │  Busy ✗      │
    │  ✅ NOTIFIED │            │  ❌ SKIPPED  │
    └──────────────┘            └──────────────┘

ROUTING TABLE:
┌───────────┬─────────────┬─────────────┬──────────────┐
│ request_id│ mechanic_id │ shop_id     │ routing_type │
├───────────┼─────────────┼─────────────┼──────────────┤
│ req-123   │ mech-1      │ shop-b-id   │ shop_based   │
└───────────┴─────────────┴─────────────┴──────────────┘
```

### Case 2: No Shop Selected (Broadcast Request)

```
┌──────────────────────────────────────────────────────────┐
│                    REQUEST DATA                          │
├──────────────────────────────────────────────────────────┤
│  id: req-456                                             │
│  preferred_shop_id: NULL ← No specific shop             │
│  request_type: 'broadcast'                               │
│  status: 'pending'                                       │
│  broadcast_radius_km: 25                                 │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  SEARCH ALL NEARBY    │
              │                       │
              │  Calculate distance   │
              │  WHERE distance < 25km│
              │  No shop filter       │
              └───────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌────────────┐    ┌────────────┐    ┌────────────┐
│ Mechanic A │    │ Mechanic B │    │ Mechanic C │
│ Shop A     │    │ Shop B     │    │ Shop C     │
│ 5 km away  │    │ 8 km away  │    │ 12 km away │
│ ✅ NOTIFIED│    │ ✅ NOTIFIED│    │ ✅ NOTIFIED│
└────────────┘    └────────────┘    └────────────┘

ROUTING TABLE:
┌───────────┬─────────────┬──────────┬──────────────┐
│ request_id│ mechanic_id │ shop_id  │ routing_type │
├───────────┼─────────────┼──────────┼──────────────┤
│ req-456   │ mech-a      │ shop-a   │ any_available│
│ req-456   │ mech-b      │ shop-b   │ any_available│
│ req-456   │ mech-c      │ shop-c   │ any_available│
└───────────┴─────────────┴──────────┴──────────────┘
```

---

## SUMMARY TABLE

| Feature | Before Fix | After Fix |
|---------|-----------|-----------|
| **Shop Filter** | ❌ No filter | ✅ Filtered by preferred_shop_id |
| **Wrong Shop Notifications** | ❌ Yes | ✅ No |
| **Busy Alert** | ❌ None | ✅ "All X mechanics busy" |
| **Empty Shop Alert** | ❌ None | ✅ "No mechanics in shop" |
| **Broadcast Mode** | ✅ Works | ✅ Works (if no shop selected) |
| **Duplicate Prevention** | ❌ Possible | ✅ Prevented |
| **Auto-trigger** | ❌ Manual | ✅ Automatic on request creation |

---

**Visual Guide Complete! Run FIX_SHOP_SPECIFIC_ROUTING.sql to implement. 🚀**
