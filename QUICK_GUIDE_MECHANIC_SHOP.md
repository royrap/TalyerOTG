# Quick Guide: Mechanic vs Shop Request Flow

## 🎯 Ano ang Pagkakaiba?

### ❌ HINDI PUMILI NG SHOP = LAHAT NG MECHANIC
```
Customer → "Find Any Available Mechanic"
    ↓
┌─────────────────────────────────────┐
│   BROADCAST TO ALL MECHANICS!       │
│                                     │
│   Within 50km radius:               │
│   ✅ Rafael (Shop A) - Notified     │
│   ✅ Pedro (Shop A) - Notified      │
│   ✅ Maria (Shop A) - Notified      │
│   ✅ Juan (Shop B) - Notified       │
│   ✅ Carlos (Independent) - Notified│
│                                     │
│   LAHAT MAKAKAKITA! 🎉              │
└─────────────────────────────────────┘
```

### ✅ PUMILI NG SHOP = SHOP MECHANICS LANG
```
Customer → "Choose Shop A"
    ↓
┌─────────────────────────────────────┐
│   SHOP A MECHANICS ONLY!            │
│                                     │
│   Shop A mechanics:                 │
│   ✅ Rafael (Shop A) - Notified     │
│   ✅ Pedro (Shop A) - Notified      │
│   ✅ Maria (Shop A) - Notified      │
│                                     │
│   NOT notified:                     │
│   ❌ Juan (Shop B)                  │
│   ❌ Carlos (Independent)           │
│                                     │
│   SHOP A LANG! 🏪                   │
└─────────────────────────────────────┘
```

---

## 📱 Customer Screen Flow

### Path 1: Broadcast (No Shop)
```
[Service Request Button]
    ↓
[Find Any Available Mechanic] ← CLICK THIS
    ↓
[Describe Issue]
    ↓
[Create Request]
    ↓
📢 Broadcast to ALL mechanics!
```

### Path 2: Shop-based
```
[Service Request Button]
    ↓
[Choose a Specific Shop] ← CLICK THIS
    ↓
[Browse Shops List]
    ↓
[Select Shop A] ← CHOOSE SHOP
    ↓
[View Shop A Services]
    ↓
[Select Service]
    ↓
[Create Request]
    ↓
🏪 Notify Shop A mechanics only!
```

---

## 🗂️ Database Differences

### Broadcast Request Data:
```json
{
  "request_type": "broadcast",
  "preferred_shop_id": null,          ← WALANG SHOP!
  "broadcast_radius_km": 50.0,        ← MALAWAK
  "can_accept_by_any_mechanic": true  ← KAHIT SINO
}
```

### Shop-based Request Data:
```json
{
  "request_type": "shop_based",
  "preferred_shop_id": "shop-123",    ← MAY SHOP!
  "broadcast_radius_km": 5.0,         ← MALIIT
  "can_accept_by_any_mechanic": false ← SHOP LANG
}
```

---

## 🔍 Who Gets Notified?

### Example Database State:
```
MECHANICS IN SYSTEM:
├─ Rafael (Shop A, 2.5km away, available)
├─ Pedro (Shop A, 3km away, available)
├─ Maria (Shop A, 4km away, available)
├─ Juan (Shop B, 5km away, available)
└─ Carlos (Independent, 10km away, available)
```

### Broadcast Request → ALL 5 NOTIFIED ✅
```
Request Type: broadcast
preferred_shop_id: null

Notifications Sent To:
✅ Rafael
✅ Pedro
✅ Maria
✅ Juan
✅ Carlos

Total: 5 mechanics
```

### Shop A Request → ONLY 3 NOTIFIED ✅
```
Request Type: shop_based
preferred_shop_id: shop-a-id

Notifications Sent To:
✅ Rafael (Shop A)
✅ Pedro (Shop A)
✅ Maria (Shop A)

NOT Notified:
❌ Juan (Shop B)
❌ Carlos (Independent)

Total: 3 mechanics
```

---

## 💡 Simple Rule

```
IF preferred_shop_id IS NULL
  THEN → Broadcast to ALL mechanics
ELSE
  THEN → Notify ONLY shop mechanics
```

**That's it! Simple lang! 🎉**

---

## 📊 Quick Stats

| Feature | Broadcast | Shop-based |
|---------|-----------|------------|
| Mechanics notified | ALL | Selected shop only |
| Radius | 50 km | 5 km |
| Response time | ⚡ Fast | 🕐 Moderate |
| Who can accept | Anyone | Shop mechanics |
| Best for | 🚨 Emergency | 📅 Planned |

---

**Key Point**: `preferred_shop_id` field determines EVERYTHING!
- **NULL** = Broadcast to all
- **shop-id** = Shop mechanics only

Simple! 🚀
