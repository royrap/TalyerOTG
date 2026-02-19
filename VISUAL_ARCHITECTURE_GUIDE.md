# 🎨 RoadAid App Architecture - Visual Guide

**Date:** October 16, 2025

---

## 📱 Invoice Payment Flow - Mobile

```
┌─────────────────────────────────────────────────────────────┐
│                    Invoice Payment Screen                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Invoice Summary                                      │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │ 📋 Invoice #AB12                                │ │  │
│  │  │ Service: Tire Repair                            │ │  │
│  │  │ Amount: ₱1,500.00                               │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  │                                                       │  │
│  │  Payment Method Selection                            │  │
│  │  ┌─────────────────┐  ┌─────────────────┐          │  │
│  │  │ 💳 Online      │  │ 💵 Cash         │          │  │
│  │  │ Payment        │  │ Payment         │          │  │
│  │  └─────────────────┘  └─────────────────┘          │  │
│  │                                                       │  │
│  │  [Proceed to Payment] ← User taps this              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Platform Detection
                            ↓
              MediaQuery.size.width < 600?
                            ↓
                          YES (Mobile)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         Bottom Sheet Payment UI (90% height)                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ━━━━  ← Drag handle                                  │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ 🔴 Complete Payment                              [✕] │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ 💳 PayMongo Payment                                  │  │
│  │ Amount: ₱1,500.00                          [🔄] [🌐] │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │                                             │    │  │
│  │  │         WebView Loads PayMongo             │    │  │
│  │  │                                             │    │  │
│  │  │  ┌───────────────────────────────────┐    │    │  │
│  │  │  │ PayMongo Checkout Page            │    │    │  │
│  │  │  │                                   │    │    │  │
│  │  │  │ [Card Number]                     │    │    │  │
│  │  │  │ [Expiry] [CVV]                    │    │    │  │
│  │  │  │ [Pay ₱1,500.00]                   │    │    │  │
│  │  │  └───────────────────────────────────┘    │    │  │
│  │  │                                             │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                                                       │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ 🔒 Secure payment powered by PayMongo                │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
                   Payment Successful
                            ↓
              Bottom Sheet Closes Automatically
                            ↓
            Returns to Invoice Screen (Updated)
```

---

## 💻 Invoice Payment Flow - Desktop

```
┌─────────────────────────────────────────────────────────────┐
│                    Invoice Payment Screen                    │
│  (Same as mobile - selection screen)                         │
│                                                               │
│  User selects "Online Payment"                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Platform Detection
                            ↓
              MediaQuery.size.width >= 600?
                            ↓
                         YES (Desktop)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│     [Screen Overlay - Semi-transparent Dark Background]      │
│                                                               │
│       ┌─────────────────────────────────────────────┐       │
│       │ Dialog (70% width, 80% height, centered)   │       │
│       │                                             │       │
│       │ ┌─────────────────────────────────────────┐│       │
│       │ │ 🔴 Complete Payment              [✕]   ││       │
│       │ ├─────────────────────────────────────────┤│       │
│       │ │ 💳 PayMongo Payment                    ││       │
│       │ │ Amount: ₱1,500.00    [Open in Browser] ││       │
│       │ ├─────────────────────────────────────────┤│       │
│       │ │                                         ││       │
│       │ │  IF NOT WEB:                            ││       │
│       │ │  ┌───────────────────────────────────┐ ││       │
│       │ │  │ WebView (PayMongo)                │ ││       │
│       │ │  │                                   │ ││       │
│       │ │  │ [Payment Form]                    │ ││       │
│       │ │  └───────────────────────────────────┘ ││       │
│       │ │                                         ││       │
│       │ │  IF WEB:                                ││       │
│       │ │  ┌───────────────────────────────────┐ ││       │
│       │ │  │ 🌐                                │ ││       │
│       │ │  │ WebView not available on web      │ ││       │
│       │ │  │                                   │ ││       │
│       │ │  │ [Open Payment Page] ← Big Button │ ││       │
│       │ │  └───────────────────────────────────┘ ││       │
│       │ │                                         ││       │
│       │ ├─────────────────────────────────────────┤│       │
│       │ │ 🔒 Secure payment powered by PayMongo  ││       │
│       │ └─────────────────────────────────────────┘│       │
│       └─────────────────────────────────────────────┘       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Mechanic Dashboard - Home Tab

```
┌─────────────────────────────────────────────────────────────┐
│                  Mechanic Dashboard - Home Tab               │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ 🟢 ONLINE                        [Toggle]  [Profile]    ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Today's Stats:                                          ││
│  │ Jobs: 3  |  Earnings: ₱4,500  |  Rating: ⭐ 4.8        ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  Main Content Area                                           │
│  (Scrollable)                                                │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │        Persistent Bottom Sheet (Active Job)             ││
│  │                                                          ││
│  │  🔴 Active Job                          [📜] [☎] [▼]   ││
│  │  ───────────────────────────────────────────────────    ││
│  │  👤 Juan Dela Cruz                                      ││
│  │  🔧 Tire Repair & Alignment                             ││
│  │  ⚡ IN PROGRESS                                          ││
│  │                                                          ││
│  │  Job Details:                                            ││
│  │  Service: Tire Repair                                    ││
│  │  Location: 123 Main St, Baliwag                         ││
│  │  Distance: 2.5 km                                        ││
│  │  ETA: ~8 min                                             ││
│  │                                                          ││
│  │  ┌────────────────────────────────────────────────────┐ ││
│  │  │ 🗺️ Google Maps                                    │ ││
│  │  │                                                    │ ││
│  │  │    🔧 ← Mechanic (You)                            │ ││
│  │  │     \                                             │ ││
│  │  │      \  Red Route Line                            │ ││
│  │  │       \  (Polyline)                               │ ││
│  │  │        \                                           │ ││
│  │  │         \                                          │ ││
│  │  │          \                                         │ ││
│  │  │           → 👤 Customer                           │ ││
│  │  │                                                    │ ││
│  │  │  [Map is draggable/zoomable/rotatable]           │ ││
│  │  └────────────────────────────────────────────────────┘ ││
│  │                                                          ││
│  │  [📋 Create Detailed Invoice]                           ││
│  │  [📷 Scan QR Code]  (enabled after invoice paid)        ││
│  │  [❌ Cancel Job]                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  [🏠] [💼] [📜] [👤] ← Bottom Navigation                    │
│   ✓    ·    ·    ·    (Home selected)                       │
└─────────────────────────────────────────────────────────────┘
```

### When Mechanic Switches Tabs:

```
Jobs Tab:                    History Tab:                Profile Tab:
┌─────────────┐             ┌─────────────┐             ┌─────────────┐
│ Jobs List   │             │ History     │             │ Profile     │
│             │             │ List        │             │ Info        │
│ (No bottom  │             │             │             │             │
│  sheet)     │             │ (No bottom  │             │ (No bottom  │
│             │             │  sheet)     │             │  sheet)     │
└─────────────┘             └─────────────┘             └─────────────┘
[🏠] [💼] [📜] [👤]        [🏠] [💼] [📜] [👤]        [🏠] [💼] [📜] [👤]
 ·    ✓    ·    ·           ·    ·    ✓    ·           ·    ·    ·    ✓

Bottom sheet ONLY visible in Home tab (index 0)
```

---

## 👥 Customer Dashboard - Home Tab

```
┌─────────────────────────────────────────────────────────────┐
│              Customer Dashboard - Home Tab                   │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Welcome, Maria! 👋                           [Profile]  ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  Main Content Area                                           │
│  (Recent services, quick actions, etc.)                      │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │      Persistent Bottom Sheet (Active Service)           ││
│  │                                                          ││
│  │  🔵 Service in Progress                  [☎] [▼]        ││
│  │  ───────────────────────────────────────────────────    ││
│  │  🔧 Pedro Santos (Mechanic)                             ││
│  │  🚗 Toyota Vios - Tire Repair                           ││
│  │  ⚡ MECHANIC ON THE WAY                                  ││
│  │                                                          ││
│  │  Service Details:                                        ││
│  │  Service: Tire Repair                                    ││
│  │  Your Location: 123 Main St                             ││
│  │  Mechanic Distance: 2.5 km away                         ││
│  │  ETA: ~8 minutes                                         ││
│  │                                                          ││
│  │  ┌────────────────────────────────────────────────────┐ ││
│  │  │ 🗺️ Google Maps                                    │ ││
│  │  │                                                    │ ││
│  │  │    🔧 ← Mechanic                                  │ ││
│  │  │     \                                             │ ││
│  │  │      \  Red Route Line                            │ ││
│  │  │       \  (Polyline showing mechanic's route)      │ ││
│  │  │        \                                           │ ││
│  │  │         \                                          │ ││
│  │  │          \                                         │ ││
│  │  │           → 📍 Your Location                      │ ││
│  │  │                                                    │ ││
│  │  │  Real-time updates as mechanic moves              │ ││
│  │  └────────────────────────────────────────────────────┘ ││
│  │                                                          ││
│  │  [☎ Contact Mechanic]                                   ││
│  │  [❌ Cancel Service]  (only if mechanic not assigned)   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  [🏠] [📍] [📜] [🧾] [👤] ← Bottom Navigation               │
│   ✓    ·    ·    ·    ·    (Home selected)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Real-Time Polyline Update Flow

```
                    MECHANIC SIDE                    CUSTOMER SIDE

    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Mechanic Opens App       │         │  Customer Sees Request    │
    │  with Active Job          │         │  Accepted by Mechanic     │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Bottom Sheet Appears     │         │  Bottom Sheet Appears     │
    │  in Home Tab              │         │  in Home Tab              │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Get Mechanic GPS         │         │  Subscribe to Mechanic    │
    │  Location                 │         │  Location Updates         │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Load Customer Location   │         │  Load Own Location        │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Call Google Directions   │         │  Call Google Directions   │
    │  API                      │         │  API                      │
    │                           │         │                           │
    │  Origin: Mechanic         │         │  Origin: Mechanic         │
    │  Destination: Customer    │         │  Destination: Customer    │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Receive Route Points     │         │  Receive Route Points     │
    │  [LatLng, LatLng, ...]    │         │  [LatLng, LatLng, ...]    │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Draw Polyline on Map     │         │  Draw Polyline on Map     │
    │  (Red, Solid, 6px width)  │         │  (Red, Solid, 6px width)  │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
          ⏰ TIMER (15s)                      🔔 REALTIME LISTENER
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  GPS Updates Every 15s    │────────>│  Supabase Realtime        │
    │                           │         │  Detects Location Change  │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Update Mechanic Location │         │  Process Location Update  │
    │  in Database              │         │                           │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Fetch New Route          │         │  Fetch New Route          │
    │  from Google API          │         │  from Google API          │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Redraw Polyline          │         │  Redraw Polyline          │
    │  with New Path            │         │  with New Path            │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Auto-Adjust Camera       │         │  Auto-Adjust Camera       │
    │  to Show Full Route       │         │  to Show Full Route       │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
    ┌───────────────────────────┐         ┌───────────────────────────┐
    │  Update Distance & ETA    │         │  Update Distance & ETA    │
    └───────────────────────────┘         └───────────────────────────┘
                ↓                                     ↓
           🔁 REPEAT                            🔁 REPEAT
     (every 15 seconds)                  (on every location update)


    📊 Update Frequency:                   📊 Update Frequency:
    - GPS: Every 15 seconds               - Realtime: ~1-2 seconds
    - Only if moved >10 meters            - Only if moved >10 meters
    - API call per update                 - API call per update
```

---

## 🎨 Color Scheme & Icons

### Payment UI:
```
🔴 Primary Red (Header):        Color(0xFFE53E3E)
💳 Blue (Payment Info):         Colors.blue
🔒 Green (Security):            Colors.green.shade600
⚪ White (Background):          Colors.white
🌫️ Gray (Borders):             Colors.grey.shade300
```

### Mechanic UI:
```
🔴 RoadAid Red (Active):        Color(0xFFEF5350)
🔧 Red (Polyline):              Color.fromARGB(255, 176, 12, 1)
🔵 Blue (Customer Marker):      Color(0xFF1976D2)
🟢 Green (Online Status):       Colors.green
⚪ White (Cards):               Colors.white
```

### Customer UI:
```
🔵 Blue (Active Service):       Colors.blue
🔴 Red (Polyline):              Color.fromARGB(255, 176, 12, 1)
🟠 Orange (Location Marker):    BitmapDescriptor.hueOrange
🔴 Red (Mechanic Marker):       BitmapDescriptor.hueRed
⚪ White (Cards):               Colors.white
```

---

## 📐 Layout Dimensions

### Mobile Bottom Sheet (Invoice Payment):
```
Height: 90% of screen height
Width: 100% of screen width
Top Padding: 10% (for drag handle area)
Border Radius: 20px (top corners only)
```

### Desktop Dialog (Invoice Payment):
```
Width: 70% of screen width
Height: 80% of screen height
Position: Centered
Border Radius: 20px (all corners)
Background Overlay: rgba(0,0,0,0.5)
```

### Bottom Sheets (Job Tracking):
```
Height: Auto (content-based)
Max Height: 60% of screen
Width: 100% of screen width
Border Radius: 20px (top corners)
Minimum Height: 200px
```

### Map Heights:
```
Mechanic Bottom Sheet Map: 300px
Customer Bottom Sheet Map: 300px
Full Screen Maps: 100% of available space
```

---

*End of Visual Guide*
