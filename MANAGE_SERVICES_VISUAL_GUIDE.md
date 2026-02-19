# 📱 MANAGE SERVICES - VISUAL GUIDE

## 🎯 Ano ang Hitsura ng New Add Service Form

```
┌─────────────────────────────────────┐
│     🔧 Add New Service              │
├─────────────────────────────────────┤
│                                     │
│  ℹ️ Add your custom service with   │
│     just the basics:                │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 🔧 Service Name *             │ │
│  │ e.g., Oil Change, Brake Repair│ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 📝 Description                │ │
│  │ Brief description of what you │ │
│  │ offer                         │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 💵 Price (₱) *                │ │
│  │ Enter your service price      │ │
│  └───────────────────────────────┘ │
│                                     │
│  * Required fields                  │
│                                     │
│     [Cancel]   [Add Service] ←───┐ │
│                            RED    │ │
└─────────────────────────────────────┘
```

---

## 📋 Service Card sa List

```
┌──────────────────────────────────────────┐
│ ┌────┐                                   │
│ │ 🔧 │  OIL CHANGE                       │
│ │RED │  ┌──────────────┐                │
│ └────┘  │  ₱1,500.00  │  [✏️] [🗑️]      │
│         └──────────────┘   EDIT DELETE   │
│            GREEN                          │
│                                          │
│ ┌─────────────────────────────────────┐ │
│ │ 📝 Full synthetic oil with filter   │ │
│ │    replacement and 10-point check   │ │
│ └─────────────────────────────────────┘ │
│               DESCRIPTION                │
└──────────────────────────────────────────┘
```

---

## 🔍 Search Bar

```
┌──────────────────────────────────────────┐
│ 🔍 Search services...             [X]    │
│                                  CLEAR   │
└──────────────────────────────────────────┘
```

---

## 📱 Full Screen Layout

```
┌────────────────────────────────────────────┐
│  ← Manage Services              🔄        │
│                              REFRESH       │
├────────────────────────────────────────────┤
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ 🔍 Search services...          [X]   │ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ ┌──┐ OIL CHANGE          [✏️] [🗑️]  │ │
│  │ │🔧│ ₱1,500                          │ │
│  │ └──┘ 📝 Full synthetic oil...       │ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ ┌──┐ BRAKE REPAIR        [✏️] [🗑️]  │ │
│  │ │🔧│ ₱2,500                          │ │
│  │ └──┘ 📝 Front & rear brake...       │ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ ┌──┐ TIRE ROTATION       [✏️] [🗑️]  │ │
│  │ │🔧│ ₱800                            │ │
│  │ └──┘ 📝 All 4 tires rotated...      │ │
│  └──────────────────────────────────────┘ │
│                                            │
│                                  ┌──────┐ │
│                                  │  +   │ │
│                                  │ Add  │ │
│                                  │Service│ │
│                                  └──────┘ │
│                                    RED    │
└────────────────────────────────────────────┘
```

---

## 🎨 Color Coding

### 🔴 RED (Primary Action)
- Add Service button (FAB)
- Service icon background
- Primary brand color

### 🔵 BLUE (Edit Action)
- Edit icon button
- Indicates modification

### 🔴 RED (Delete Action)
- Delete icon button
- Warning/destructive action

### 🟢 GREEN (Price Display)
- Price badge
- Positive value indicator

### ⚪ GRAY (Neutral)
- Description box
- Card borders
- Secondary text

---

## 📝 Field Examples

### Service Name Examples:
```
✅ Good:
- "Oil Change"
- "Brake Pad Replacement"
- "Engine Diagnostic"
- "Aircon Service"
- "Tire Alignment"

❌ Too Vague:
- "Service"
- "Fix"
- "Repair"
```

### Description Examples:
```
✅ Good:
- "Includes full synthetic oil, filter replacement, and 10-point inspection"
- "Front and rear brake pad replacement with labor"
- "Complete aircon system cleaning and recharge"

❌ Not Helpful:
- "Repair service"
- "We fix it"
- "" (empty)
```

### Price Examples:
```
✅ Good:
- 1500 (for Oil Change)
- 2500 (for Brake Repair)
- 3000 (for Aircon Service)

❌ Wrong Format:
- "1500 pesos" (just numbers)
- "1,500" (no commas, just 1500)
- "free" (must be number)
```

---

## 🔄 User Flow Diagram

```
START
  │
  ▼
Open Manage Services
  │
  ├─→ View List of Services
  │     │
  │     ├─→ Search Service
  │     │     └─→ Filter Results
  │     │
  │     ├─→ Edit Service
  │     │     └─→ Update Fields
  │     │           └─→ Save
  │     │
  │     └─→ Delete Service
  │           └─→ Confirm
  │                 └─→ Remove
  │
  └─→ Add New Service
        │
        ├─→ Fill Form
        │     ├─ Service Name ✅
        │     ├─ Description (optional)
        │     └─ Price ✅
        │
        └─→ Submit
              │
              ├─→ Validate
              │     ├─ Name empty? → ERROR
              │     ├─ Price invalid? → ERROR
              │     └─ All OK → Continue
              │
              └─→ Save to Database
                    │
                    └─→ Success! ✅
                          └─→ Refresh List
```

---

## 💾 Database Flow

```
FLUTTER APP                 SUPABASE                DATABASE
    │                          │                       │
    │  1. Add Service          │                       │
    ├─────────────────────────→│                       │
    │                          │  2. Check RLS         │
    │                          ├──────────────────────→│
    │                          │                       │
    │                          │  3. RLS OK?           │
    │                          │←──────────────────────┤
    │                          │       YES ✅          │
    │                          │                       │
    │                          │  4. INSERT            │
    │                          ├──────────────────────→│
    │                          │                       │
    │                          │  5. Row ID            │
    │                          │←──────────────────────┤
    │                          │                       │
    │  6. Success Response     │                       │
    │←─────────────────────────┤                       │
    │                          │                       │
    │  7. Show Success Message │                       │
    │  8. Refresh List         │                       │
    │                          │                       │
```

---

## 🔒 Security Flow

```
User tries to:
    │
    ├─→ View Services
    │     └─→ RLS Check: Is this their shop?
    │           ├─ YES → Show services ✅
    │           └─ NO → Empty list
    │
    ├─→ Add Service
    │     └─→ RLS Check: Do they own this shop?
    │           ├─ YES → Allow insert ✅
    │           └─ NO → Error 403
    │
    ├─→ Edit Service
    │     └─→ RLS Check: Is this their shop's service?
    │           ├─ YES → Allow update ✅
    │           └─ NO → Error 403
    │
    └─→ Delete Service
          └─→ RLS Check: Is this their shop's service?
                ├─ YES → Allow delete ✅
                └─ NO → Error 403
```

---

## 📊 Data Structure

### Service Object:
```json
{
  "id": "uuid-here",
  "shop_id": "shop-uuid-here",
  "service_name": "Oil Change",
  "description": "Full synthetic oil with filter",
  "base_price": 1500.00,
  "is_custom": true,
  "is_active": true,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Flutter State:
```dart
List<Map<String, dynamic>> _services = [
  {
    'id': 'uuid-1',
    'service_name': 'Oil Change',
    'description': 'Full synthetic...',
    'base_price': 1500.00,
    ...
  },
  {
    'id': 'uuid-2',
    'service_name': 'Brake Repair',
    'description': 'Front & rear...',
    'base_price': 2500.00,
    ...
  }
];
```

---

## 🎯 Key Points to Remember

### ✅ DO:
- Keep service names clear and specific
- Add helpful descriptions
- Use realistic prices
- Test after adding

### ❌ DON'T:
- Use special characters in names
- Leave price empty
- Add duplicate service names
- Forget to save changes

---

## 🚀 Quick Start Guide

1. **Login** as Talyer Owner
2. **Navigate** to Manage Services
3. **Tap** the red "Add Service" button
4. **Fill** the 3 fields:
   - Name: "Brake Repair"
   - Description: "Front and rear brake service"
   - Price: 2500
5. **Tap** "Add Service"
6. **Done!** Service appears in list

---

**Simple lang talaga ngayon! 🎉**

Just 3 fields:
1. Name
2. Description
3. Price

Tapos na! Add, Edit, Delete - lahat nandyan na! ✅
