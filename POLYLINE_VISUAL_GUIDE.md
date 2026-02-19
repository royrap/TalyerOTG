# Real-Time Polyline Synchronization - Visual Guide

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SUPABASE DATABASE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────┐         ┌──────────────────────┐        │
│  │ mechanic_locations   │         │  service_requests     │        │
│  ├──────────────────────┤         ├──────────────────────┤        │
│  │ user_id             │         │ id                   │        │
│  │ latitude  ◄─────────┼─────────┼─► pickup_latitude    │        │
│  │ longitude           │         │ pickup_longitude     │        │
│  │ updated_at          │         │ assigned_mechanic_id │        │
│  └──────────────────────┘         └──────────────────────┘        │
│           ▲                                 ▲                       │
│           │ Real-Time Stream                │ Real-Time Stream      │
│           │                                 │                       │
└───────────┼─────────────────────────────────┼───────────────────────┘
            │                                 │
            │                                 │
┌───────────┼─────────────────────────────────┼───────────────────────┐
│           │        GOOGLE MAPS API          │                       │
│           │                                 │                       │
│  ┌────────▼──────────┐           ┌─────────▼────────┐             │
│  │  getRoutePoints() │           │ getDistanceMatrix│             │
│  │  ────────────────►│───────────►│◄────────────────│             │
│  │  Returns: List    │           │ Returns: dist &  │             │
│  │  of LatLng points │           │ duration         │             │
│  └───────────────────┘           └──────────────────┘             │
│           │                                 │                       │
└───────────┼─────────────────────────────────┼───────────────────────┘
            │                                 │
            ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT SIDE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────┐    ┌──────────────────────────┐     │
│  │   MECHANIC APP           │    │   CUSTOMER APP           │     │
│  │                          │    │                          │     │
│  │  ┌─────────────────┐    │    │  ┌─────────────────┐    │     │
│  │  │ GoogleMap       │    │    │  │ GoogleMap       │    │     │
│  │  │ ┌─────────────┐ │    │    │  │ ┌─────────────┐ │    │     │
│  │  │ │   Marker    │ │    │    │  │ │   Marker    │ │    │     │
│  │  │ │  (Mechanic) │ │    │    │  │ │  (Mechanic) │ │    │     │
│  │  │ └──────┬──────┘ │    │    │  │ └──────┬──────┘ │    │     │
│  │  │        │        │    │    │  │        │        │    │     │
│  │  │   ┌────▼────┐   │    │    │  │   ┌────▼────┐   │    │     │
│  │  │   │POLYLINE │◄──┼────┼────┼──┼──►│POLYLINE │   │    │     │
│  │  │   │  (Route)│   │    │    │  │   │  (Route)│   │    │     │
│  │  │   └────┬────┘   │    │    │  │   └────┬────┘   │    │     │
│  │  │        │        │    │    │  │        │        │    │     │
│  │  │ ┌──────▼──────┐ │    │    │  │ ┌──────▼──────┐ │    │     │
│  │  │ │   Marker    │ │    │    │  │ │   Marker    │ │    │     │
│  │  │ │  (Customer) │ │    │    │  │ │  (Customer) │ │    │     │
│  │  │ └─────────────┘ │    │    │  │ └─────────────┘ │    │     │
│  │  └─────────────────┘    │    │  └─────────────────┘    │     │
│  │                          │    │                          │     │
│  └──────────────────────────┘    └──────────────────────────┘     │
│         ▲                                  ▲                       │
│         │                                  │                       │
│         │ Updates every 15s                │ Updates on location   │
│         │ or when moved >10m               │ change (real-time)    │
│         │                                  │                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

### Scenario 1: Mechanic Accepts Job

```
┌─────────┐                     ┌─────────┐                   ┌─────────┐
│ Mechanic│                     │Supabase │                   │Customer │
│   App   │                     │Database │                   │   App   │
└────┬────┘                     └────┬────┘                   └────┬────┘
     │                               │                             │
     │ 1. Accept Job                 │                             │
     ├──────────────────────────────►│                             │
     │                               │                             │
     │ 2. Get Customer Location      │                             │
     │◄──────────────────────────────┤                             │
     │                               │                             │
     │ 3. Fetch Route from API       │                             │
     ├──────────────────────►[Google Maps API]                     │
     │                               │                             │
     │ 4. Receive Route Points       │                             │
     │◄──────────────────────[Google Maps API]                     │
     │                               │                             │
     │ 5. Draw Polyline              │                             │
     │   (Red Dashed Line)           │                             │
     │                               │                             │
     │ 6. Update Mechanic Location   │                             │
     ├──────────────────────────────►│                             │
     │                               │                             │
     │                               │ 7. Real-time Event          │
     │                               ├────────────────────────────►│
     │                               │                             │
     │                               │ 8. Get Mechanic Location    │
     │                               │◄────────────────────────────┤
     │                               │                             │
     │                               │ 9. Fetch Route from API     │
     │                               │────────►[Google Maps API]   │
     │                               │                             │
     │                               │ 10. Receive Route Points    │
     │                               │◄────────[Google Maps API]   │
     │                               │                             │
     │                               │ 11. Draw Polyline           │
     │                               │    (Same Red Dashed Line)   │
     │                               │                             │
```

### Scenario 2: Mechanic Moves During Service

```
┌─────────┐                     ┌─────────┐                   ┌─────────┐
│ Mechanic│                     │Supabase │                   │Customer │
│   App   │                     │Database │                   │   App   │
└────┬────┘                     └────┬────┘                   └────┬────┘
     │                               │                             │
     │ 1. Location Update (GPS)      │                             │
     │   Every 15s or >10m move      │                             │
     │                               │                             │
     │ 2. Update Location in DB      │                             │
     ├──────────────────────────────►│                             │
     │                               │                             │
     │ 3. Redraw Polyline            │                             │
     │   (New Route)                 │                             │
     │                               │                             │
     │                               │ 4. Real-time Event          │
     │                               │    "mechanic moved"         │
     │                               ├────────────────────────────►│
     │                               │                             │
     │                               │ 5. Get New Location         │
     │                               │◄────────────────────────────┤
     │                               │                             │
     │                               │ 6. Fetch Updated Route      │
     │                               │────────►[Google Maps API]   │
     │                               │                             │
     │                               │ 7. Receive New Route        │
     │                               │◄────────[Google Maps API]   │
     │                               │                             │
     │                               │ 8. Redraw Polyline          │
     │                               │    (Updated Route)          │
     │                               │                             │
     │   ◄─────────────────────────────────────────────────────────┤
     │          Both maps now show the SAME updated route          │
     │   ─────────────────────────────────────────────────────────►│
```

## Polyline Styling Comparison

```
┌──────────────────────────────────────────────────────────────┐
│                  PRIMARY ROUTE (API Success)                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Color: #B00C01 (RoadAid Red)                               │
│  Width: 5px                                                  │
│  Pattern: ─────  ─────  ─────  ─────  ─────                │
│            30px   15px   30px   15px   30px                 │
│            dash   gap    dash   gap    dash                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                                                        │ │
│  │  [Mechanic] ═════  ═════  ═════  ═════ [Customer]    │ │
│  │             ▼                                          │ │
│  │        Following roads                                 │ │
│  │        and turns                                       │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                FALLBACK ROUTE (API Failure)                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Color: #B00C01 with 70% opacity                            │
│  Width: 4px                                                  │
│  Pattern: ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·         │
│            10px gap between dots                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                                                        │ │
│  │  [Mechanic] · · · · · · · · · · · · · [Customer]     │ │
│  │             ▼                                          │ │
│  │        Direct straight line                            │ │
│  │        (as the crow flies)                             │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Map View Example

```
╔══════════════════════════════════════════════════════════════╗
║                    CUSTOMER'S MAP VIEW                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║    [🔍]                                      [@] [+] [-]    ║
║                                                              ║
║                                                              ║
║              🚗 Mechanic (Moving)                           ║
║               │                                              ║
║               ╰──── 2.3 km ────╮                           ║
║                                │                             ║
║                               ═│══ Main Road ══              ║
║                                │                             ║
║                                │                             ║
║                               ═╯                             ║
║                               ║                              ║
║                               ║                              ║
║                          ════╝ Turn Left                    ║
║                          ║                                   ║
║                          ║                                   ║
║                     ════╝ Landmark St.                      ║
║                     │                                        ║
║                     │                                        ║
║                     📍 Your Location                        ║
║                                                              ║
║  ┌──────────────────────────────────────────────────────┐  ║
║  │ 📍 Mechanic: 2.3 km away • ETA: 5 mins              │  ║
║  │ ─────────────────────────────────────────────────    │  ║
║  │ Route: Via Main Road & Landmark St.                  │  ║
║  └──────────────────────────────────────────────────────┘  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

```
╔══════════════════════════════════════════════════════════════╗
║                    MECHANIC'S MAP VIEW                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║    [🔍]                                      [@] [+] [-]    ║
║                                                              ║
║                                                              ║
║              🚗 Your Location (Me)                          ║
║               │                                              ║
║               ╰──── 2.3 km ────╮                           ║
║                                │                             ║
║                               ═│══ Main Road ══              ║
║                                │                             ║
║                                │                             ║
║                               ═╯                             ║
║                               ║                              ║
║                               ║                              ║
║                          ════╝ Turn Left                    ║
║                          ║                                   ║
║                          ║                                   ║
║                     ════╝ Landmark St.                      ║
║                     │                                        ║
║                     │                                        ║
║                     📍 Customer Location                    ║
║                                                              ║
║  ┌──────────────────────────────────────────────────────┐  ║
║  │ 🎯 Customer: 2.3 km away • ETA: 5 mins              │  ║
║  │ ─────────────────────────────────────────────────    │  ║
║  │ Route: Via Main Road & Landmark St.                  │  ║
║  │ [Navigate] [Call Customer] [Message]                 │  ║
║  └──────────────────────────────────────────────────────┘  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Note**: Both maps show the SAME route with the SAME polyline! ✅

## Update Frequency

```
TIME    MECHANIC SIDE                           CUSTOMER SIDE
─────   ────────────────────────────────────   ────────────────────────────
00:00   📍 Location Update (GPS)                
        └─► Update DB                           
        └─► Redraw Polyline                     
                                                 ↓
00:01                                            📡 Real-time Event Received
                                                 └─► Fetch New Location
                                                 └─► Redraw Polyline ✓
                                                 
00:15   📍 Location Update (GPS)                
        └─► Update DB                           
        └─► Redraw Polyline                     
                                                 ↓
00:16                                            📡 Real-time Event Received
                                                 └─► Redraw Polyline ✓
                                                 
00:30   📍 Location Update (GPS)                
        └─► Update DB                           
        └─► Redraw Polyline                     
                                                 ↓
00:31                                            📡 Real-time Event Received
                                                 └─► Redraw Polyline ✓
```

**Latency**: Typically 1-2 seconds for polyline updates across devices

## Key Implementation Points

### ✅ Customer Side (`main.dart`)
- **New Methods**: `_drawPolyline()`, `_drawStraightLinePolyline()`
- **Updated Methods**: `_getCurrentLocation()`, `_updateMechanicLocationFromDatabase()`, `_processMechanicLocationUpdate()`
- **Trigger**: Mechanic location changes in database

### ✅ Mechanic Side (`mechanic_job_tracking_bottom_sheet.dart`)
- **Existing Method**: `_showRouteAutomatically()` (already working)
- **Update Frequency**: Every 15 seconds + significant moves (>10m)
- **Trigger**: Timer-based + GPS location changes

### 🎯 Synchronization
- Both sides fetch routes from Google Maps API
- Both sides use same polyline styling
- Both sides update within 1-2 seconds of each other
- Both sides gracefully fallback to straight lines

## Benefits

✅ **Visual Clarity**: Clear route visualization
✅ **Real-Time Sync**: Updates across devices
✅ **Professional UX**: Matches industry standards (Uber/Grab)
✅ **User Trust**: Transparency in mechanic location
✅ **Accurate ETA**: Route-based calculations
✅ **Smooth Experience**: Automatic updates without user action

---

**Implementation Status**: ✅ COMPLETE AND READY FOR TESTING
