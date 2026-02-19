# Request Flow - Mechanic vs Shop (Tagalog Guide)

## 🎯 Dalawang Paraan ng Pag-request ng Service

Pag nag-request ang customer ng service, may **DALAWANG OPTIONS** siya:

### Option 1: Find Any Available Mechanic (Hindi pumili ng Shop)
**Direct Mechanic Request / Broadcast Request**

### Option 2: Choose a Specific Shop (Pumili ng Shop)
**Shop-based Request**

---

## 📱 FLOW 1: Hindi Pumili ng Shop (Broadcast Request)

### Ano ang Mangyayari?

```
CUSTOMER SIDE:
┌────────────────────────────────────┐
│  1. Customer clicks:               │
│     "Find Any Available Mechanic"  │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  2. Describe Issue:                │
│     - Service Type                 │
│     - Description                  │
│     - Vehicle Info                 │
│     - Photos (optional)            │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  3. Create Request Button          │
│     request_type: 'broadcast'      │
│     preferred_shop_id: NULL        │
│     broadcast_radius_km: 50.0      │
└────────────────────────────────────┘
           ↓
DATABASE:
┌────────────────────────────────────┐
│  4. System finds ALL mechanics:    │
│     - Within 50km radius           │
│     - Status = 'available'         │
│     - is_active = true             │
│                                    │
│  Example:                          │
│  ├─ Rafael (2.5km away)            │
│  ├─ Juan (5km away)                │
│  ├─ Pedro (10km away)              │
│  ├─ Maria (15km away)              │
│  └─ Carlos (20km away)             │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  5. Create routing entries:        │
│     INSERT INTO request_broadcasts │
│     FOR EACH MECHANIC              │
│                                    │
│  ✅ Rafael - notified              │
│  ✅ Juan - notified                │
│  ✅ Pedro - notified               │
│  ✅ Maria - notified               │
│  ✅ Carlos - notified              │
└────────────────────────────────────┘
           ↓
MECHANIC SIDE (LAHAT MAKAKAKITA):
┌────────────────────────────────────┐
│  📬 POPUP SA LAHAT NG MECHANICS!   │
│                                    │
│  ┌──────────────────────────────┐ │
│  │  NEW JOB REQUEST!            │ │
│  │  Customer: John Doe          │ │
│  │  Location: Quezon City       │ │
│  │  Service: Battery Jump       │ │
│  │  Distance: 2.5 km            │ │
│  │                              │ │
│  │  [Accept]  [Decline]         │ │
│  └──────────────────────────────┘ │
│                                    │
│  LAHAT ng mechanic nakakakita!    │
│  - Rafael ✓                        │
│  - Juan ✓                          │
│  - Pedro ✓                         │
│  - Maria ✓                         │
│  - Carlos ✓                        │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  6. First to Accept WINS!          │
│                                    │
│  Scenario: Juan accepts first      │
│  - Juan's popup → "Accepted!"      │
│  - Other popups auto-close         │
│  - Request assigned to Juan        │
└────────────────────────────────────┘
```

### Sino ang Makakakita?
✅ **LAHAT** ng available mechanics within 50km radius
✅ **KAHIT SAAN** shop sila (or walang shop)
✅ **UNANG TAO** na mag-accept ang makakakuha ng job

### Advantages:
- ✅ **Mabilis** - Maraming mechanic ang makakakita
- ✅ **Competitive** - Mas mataas chance na may mag-accept
- ✅ **Flexible** - Hindi limitado sa specific shop

### Disadvantages:
- ❌ Hindi alam kung sino ang mechanic (until acceptance)
- ❌ Walang guaranteed facilities/equipment
- ❌ Prices may vary

---

## 🏪 FLOW 2: Pumili ng Specific Shop (Shop-based Request)

### Ano ang Mangyayari?

```
CUSTOMER SIDE:
┌────────────────────────────────────┐
│  1. Customer clicks:               │
│     "Choose a Specific Shop"       │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  2. Shop Selection Screen:         │
│                                    │
│  📍 Nearby Shops:                  │
│  ┌──────────────────────────────┐ │
│  │ ⭐⭐⭐⭐⭐ Shop A (5.0)        │ │
│  │ 📍 2.5 km • Open              │ │
│  │ 💰 ₱300-800 • 15 services    │ │
│  │ 👨‍🔧 3 mechanics available       │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ ⭐⭐⭐⭐ Shop B (4.2)          │ │
│  │ 📍 5 km • Open                │ │
│  │ 💰 ₱250-600 • 12 services    │ │
│  │ 👨‍🔧 2 mechanics available       │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  3. Customer selects "Shop A"      │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  4. Service Selection Screen:      │
│                                    │
│  Shop A Services:                  │
│  ┌──────────────────────────────┐ │
│  │ 🔋 Battery Replacement       │ │
│  │    ₱800 • ~30 mins           │ │
│  │    [Select]                  │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ 🔧 Oil Change                │ │
│  │    ₱500 • ~20 mins           │ │
│  │    [Select]                  │ │
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │ ✏️ Request Custom Service    │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  5. Create Request Button          │
│     request_type: 'shop_based'     │
│     preferred_shop_id: 'shop_a_id' │
│     broadcast_radius_km: 5.0       │
│     can_accept_by_any_mechanic:    │
│       false                        │
└────────────────────────────────────┘
           ↓
DATABASE:
┌────────────────────────────────────┐
│  6. System finds ONLY mechanics    │
│     FROM SHOP A:                   │
│                                    │
│  Query:                            │
│  SELECT * FROM shop_mechanics      │
│  WHERE shop_id = 'shop_a_id'       │
│    AND is_active = true            │
│                                    │
│  Results:                          │
│  ├─ Rafael (Shop A mechanic) ✓     │
│  ├─ Pedro (Shop A mechanic) ✓      │
│  └─ Maria (Shop A mechanic) ✓      │
│                                    │
│  NOT INCLUDED:                     │
│  ✗ Juan (Shop B mechanic)          │
│  ✗ Carlos (Independent mechanic)   │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  7. Create routing entries:        │
│     INSERT INTO request_broadcasts │
│     ONLY FOR SHOP A MECHANICS      │
│                                    │
│  ✅ Rafael (Shop A) - notified     │
│  ✅ Pedro (Shop A) - notified      │
│  ✅ Maria (Shop A) - notified      │
│                                    │
│  NOT NOTIFIED:                     │
│  ❌ Juan (Shop B)                  │
│  ❌ Carlos (Independent)           │
└────────────────────────────────────┘
           ↓
MECHANIC SIDE (SHOP A MECHANICS LANG):
┌────────────────────────────────────┐
│  📬 POPUP SA SHOP A MECHANICS LANG!│
│                                    │
│  ┌──────────────────────────────┐ │
│  │  NEW JOB REQUEST!            │ │
│  │  Customer: John Doe          │ │
│  │  Shop: Shop A                │ │
│  │  Service: Battery Replace    │ │
│  │  Price: ₱800                 │ │
│  │                              │ │
│  │  [Accept]  [Decline]         │ │
│  └──────────────────────────────┘ │
│                                    │
│  SHOP A mechanics lang nakakakita: │
│  - Rafael (Shop A) ✓               │
│  - Pedro (Shop A) ✓                │
│  - Maria (Shop A) ✓                │
│                                    │
│  HINDI MAKIKITA:                   │
│  - Juan (Shop B) ✗                 │
│  - Carlos (Independent) ✗          │
└────────────────────────────────────┘
           ↓
┌────────────────────────────────────┐
│  8. Any Shop A mechanic accepts    │
│                                    │
│  Scenario: Rafael accepts          │
│  - Rafael: "Accepted!"             │
│  - Pedro's popup: closes           │
│  - Maria's popup: closes           │
│  - Request assigned to Rafael      │
│    (Shop A)                        │
└────────────────────────────────────┘
```

### Sino ang Makakakita?
✅ **SHOP A MECHANICS LANG** - Yung nasa selected shop
✅ **LIMITED** - 3 mechanics lang (example)
✅ **GUARANTEED** shop facilities/equipment

### Advantages:
- ✅ **Specific Shop** - Alam mo kung saan shop
- ✅ **Professional Facilities** - May equipment, tools
- ✅ **Known Prices** - Nakita mo na ang rates
- ✅ **Shop Reputation** - May ratings and reviews
- ✅ **Accountability** - May shop owner na responsible

### Disadvantages:
- ❌ **Limited Mechanics** - Less chance of quick acceptance
- ❌ **Possibly Higher Prices** - Shop overhead costs
- ❌ **Less Urgent** - For planned maintenance

---

## 🔍 TECHNICAL COMPARISON

### Database Queries:

#### BROADCAST REQUEST (No Shop Selected):
```sql
-- Find ALL available mechanics within 50km
SELECT 
    m.user_id,
    m.shop_id,
    mas.current_status
FROM mechanics m
JOIN mechanic_availability_status mas 
    ON m.user_id = mas.mechanic_id
WHERE 
    mas.current_status = 'available'
    AND mas.is_accepting_requests = true
    AND m.is_active = true
    AND ST_Distance(
        ST_MakePoint(m.current_location_lng, m.current_location_lat),
        ST_MakePoint(:customer_lng, :customer_lat)
    ) <= 50000; -- 50km radius

-- Result: ALL mechanics (Rafael, Juan, Pedro, Maria, Carlos)
```

#### SHOP-BASED REQUEST (Shop Selected):
```sql
-- Find ONLY mechanics from selected shop
SELECT 
    sm.mechanic_id,
    sm.shop_id,
    mas.current_status
FROM shop_mechanics sm
JOIN mechanic_availability_status mas 
    ON sm.mechanic_id = mas.mechanic_id
WHERE 
    sm.shop_id = :selected_shop_id
    AND sm.is_active = true
    AND mas.current_status = 'available'
    AND mas.is_accepting_requests = true;

-- Result: ONLY Shop A mechanics (Rafael, Pedro, Maria)
-- NOT included: Juan (Shop B), Carlos (Independent)
```

### Request Data Structure:

#### BROADCAST REQUEST:
```json
{
  "request_id": "req-123",
  "customer_id": "cust-456",
  "request_type": "broadcast",
  "preferred_shop_id": null,
  "is_broadcast_request": true,
  "can_accept_by_any_mechanic": true,
  "broadcast_radius_km": 50.0,
  "service_type": "Battery Jump Start",
  "description": "Battery died...",
  "status": "pending"
}
```

#### SHOP-BASED REQUEST:
```json
{
  "request_id": "req-789",
  "customer_id": "cust-456",
  "request_type": "shop_based",
  "preferred_shop_id": "shop-abc",
  "is_broadcast_request": false,
  "can_accept_by_any_mechanic": false,
  "broadcast_radius_km": 5.0,
  "service_type": "Battery Replacement",
  "service_category_id": "cat-123",
  "selected_service_price": 800.00,
  "description": "Need new battery...",
  "status": "pending"
}
```

---

## 📊 SIDE-BY-SIDE COMPARISON

| Feature | Broadcast Request (No Shop) | Shop-based Request |
|---------|---------------------------|-------------------|
| **Who sees request?** | ALL mechanics within 50km | Only selected shop's mechanics |
| **Number of mechanics** | Many (10-50+) | Few (2-5) |
| **Response time** | ⚡ Very Fast | 🕐 Moderate |
| **Price range** | 💵 Variable | 💰 Fixed/Listed |
| **Facilities** | ❓ Unknown | ✅ Professional shop |
| **Equipment** | ❓ Limited | ✅ Full toolset |
| **Accountability** | 👤 Individual | 🏪 Shop + Owner |
| **Best for** | 🚨 Emergencies | 📅 Planned service |
| **Radius** | 50 km | 5 km |
| **Database field** | `preferred_shop_id: null` | `preferred_shop_id: 'shop_id'` |
| **Routing type** | `broadcast` | `shop_based` |

---

## 🎯 WHEN TO USE WHICH?

### Use **BROADCAST REQUEST** (No Shop) kung:
- ✅ **EMERGENCY** - Battery died, flat tire, won't start
- ✅ **URGENCY** - Kailangan ng mabilis na tulong
- ✅ **FLEXIBILITY** - Okay kahit sino basta qualified
- ✅ **BUDGET** - Looking for competitive rates
- ✅ **LOCATION** - Remote area, walang malapit na shop

### Use **SHOP-BASED REQUEST** kung:
- ✅ **PLANNED MAINTENANCE** - Oil change, tune-up, inspection
- ✅ **MAJOR REPAIRS** - Engine work, transmission, complex issues
- ✅ **WARRANTY** - Want documented service history
- ✅ **TRUST** - Prefer established shop with reviews
- ✅ **EQUIPMENT NEEDED** - Special tools required

---

## 🔄 COMPLETE USER JOURNEY

### SCENARIO A: Emergency Situation (Broadcast)
```
7:00 AM - John's car won't start
7:01 AM - Opens RoadAid app
7:02 AM - Selects "Find Any Available Mechanic"
7:03 AM - Describes problem, adds photos
7:04 AM - Creates request
7:04 AM - System broadcasts to 23 mechanics
7:05 AM - Rafael (2.5km away) accepts
7:06 AM - Rafael heading to location
7:25 AM - Rafael arrives, diagnoses issue
7:40 AM - Battery jumped, car running
7:45 AM - Payment completed, job done

Total time: 45 minutes ⚡
```

### SCENARIO B: Scheduled Maintenance (Shop-based)
```
Monday 9:00 AM - Maria needs oil change
Monday 9:05 AM - Opens RoadAid app
Monday 9:10 AM - Selects "Choose a Specific Shop"
Monday 9:15 AM - Browses shops, compares prices
Monday 9:20 AM - Selects "Shop A" (4.5 stars, ₱500)
Monday 9:22 AM - Selects "Oil Change" service
Monday 9:25 AM - Creates request
Monday 9:25 AM - Only Shop A mechanics notified (3)
Monday 9:30 AM - Pedro (Shop A) accepts
Monday 9:35 AM - Maria schedules for Wednesday 2 PM
Wednesday 2:00 PM - Maria arrives at Shop A
Wednesday 2:15 PM - Oil change started
Wednesday 2:35 PM - Service completed
Wednesday 2:40 PM - Payment completed, receipt given

Total time: Scheduled appointment ✅
```

---

## 💡 KEY TAKEAWAYS

### Para sa CUSTOMERS:
1. **May CHOICE ka** - Broadcast o Shop-based
2. **Emergency = Broadcast** - Mabilis, maraming options
3. **Planned = Shop-based** - Professional, may facilities
4. **Transparency** - Alam mo kung sino at magkano

### Para sa MECHANICS:
1. **Independent mechanics** - Makakakuha ng broadcast requests
2. **Shop mechanics** - Makakakuha ng both (broadcast + shop requests)
3. **Fair distribution** - Right requests sa right people
4. **No spam** - Hindi ka makakakuha ng irrelevant requests

### Para sa SHOP OWNERS:
1. **Targeted requests** - Customers specifically choose your shop
2. **Professional image** - Showcase services and prices
3. **Loyal customers** - Build reputation through reviews
4. **Revenue tracking** - Know which services are popular

---

## ✅ SUMMARY

**BROADCAST REQUEST (No Shop)**
- ✅ ALL mechanics within 50km
- ✅ Fast response
- ✅ Competitive pricing
- ✅ Good for emergencies

**SHOP-BASED REQUEST**
- ✅ ONLY selected shop mechanics
- ✅ Professional facilities
- ✅ Known pricing
- ✅ Good for planned service

**Both systems work together to serve different customer needs!** 🚗💨

---

**Date**: October 2, 2025  
**Status**: ✅ BOTH SYSTEMS WORKING  
**Files**: Multiple (see FIXED_CUSTOMER_REQUEST_FLOW.md)
