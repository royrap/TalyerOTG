# 🎨 New Talyer Owner Dashboard Design

## Dashboard Overview Layout

### 1. 📊 Summary Cards (Top Section)
- **Total Jobs Today** - Card with count + icon
- **Total Jobs This Week** - Card with count + icon  
- **Total Jobs This Month** - Card with count + icon
- **Shop Earnings (Today/Week/Month)** - Toggle view

### 2. ⚙️ Mechanics Status Section
- **Active vs Available Mechanics**
  - Progress bar showing: "3/5 mechanics available"
  - Visual indicator (green=available, red=busy)
  - Quick list of mechanic names with status

### 3. 💸 Earnings Breakdown
- **Total Earnings Display**
  - Shop's Share (20% commission)
  - Mechanics' Total Share (75% split among mechanics)
  - Platform Fee (5%)
- **Visual breakdown** (pie chart or bars)

### 4. 🚗 Ongoing Services Table
- **List/Table showing:**
  - Customer Name
  - Vehicle (brand, model, plate)
  - Service Type
  - Assigned Mechanic
  - Status (with colored badge)
  - Time Started
  - Action buttons (View Details, Track)

### 5. Quick Actions (Bottom or Side)
- 📞 Incoming Requests (badge with count)
- 👷 Manage Mechanics
- 🔧 Manage Services  
- 📈 View Full Analytics
- 💰 Earnings Report

---

## Implementation Plan

### Data to Fetch:
1. **Jobs Summary** (today, this week, this month)
2. **Mechanics Status** (total, available, busy)
3. **Earnings Data** (shop share, mechanic share, platform fee)
4. **Active Service Requests** (ongoing jobs with details)

### Services Needed:
- `TalyerOwnerService.getDashboardSummary()`
- `ShopMechanicService.getMechanicsStatus()`
- `EarningsService.getShopEarningsSummary()`
- `ServiceRequestService.getOngoingRequests(shopId)`

---

## Color Scheme
- **Primary**: Orange/Red (#B00C01)
- **Success**: Green (available mechanics, completed)
- **Warning**: Orange (in progress)
- **Danger**: Red (busy, urgent)
- **Background**: Light grey (#F5F5F5)

---

**Implementation Date**: October 6, 2025
**Status**: Ready to implement
