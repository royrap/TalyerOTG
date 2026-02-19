# Mechanic Bottom Sheet Behavior - Visual Flow

## 🎯 Bottom Sheet Visibility Logic

```
┌─────────────────────────────────────────────────────────┐
│           MECHANIC DASHBOARD TABS                       │
├──────────┬──────────┬──────────┬─────────────────────┤
│   Home   │   Jobs   │ History  │      Profile        │
│  (TAB 0) │  (TAB 1) │ (TAB 2)  │      (TAB 3)        │
└──────────┴──────────┴──────────┴─────────────────────┘
     ↓
     │ Bottom Sheet ONLY shows on HOME TAB (index 0)
     ↓
```

## 📊 Job Status Flow with Bottom Sheet

```
┌──────────────────┐
│  JOB ACCEPTED    │ ← Bottom Sheet APPEARS ✅
└────────┬─────────┘
         ↓
┌──────────────────┐
│  INVOICE SENT    │ ← Bottom Sheet VISIBLE ✅
└────────┬─────────┘
         ↓
┌──────────────────┐
│ INVOICE ACCEPTED │ ← Bottom Sheet VISIBLE ✅
└────────┬─────────┘
         ↓
┌──────────────────┐
│  INVOICE PAID    │ ← Bottom Sheet VISIBLE ✅ [PREVIOUSLY HIDDEN ❌]
└────────┬─────────┘   [THIS WAS THE BUG - NOW FIXED!]
         ↓
┌──────────────────┐
│  IN PROGRESS     │ ← Bottom Sheet VISIBLE ✅
└────────┬─────────┘
         ↓
┌──────────────────┐
│  READY FOR QR    │ ← Bottom Sheet VISIBLE ✅
└────────┬─────────┘
         ↓
┌──────────────────┐
│    COMPLETED     │ ← Bottom Sheet DISAPPEARS ❌
└──────────────────┘
```

## 🔄 Tab Navigation Behavior

```
HOME TAB (Active Job Exists)
├─ Bottom Sheet: ✅ VISIBLE
├─ Job Details: ✅ DISPLAYED
├─ QR Scanner Button: ✅ AVAILABLE (when invoice paid)
└─ Navigation: Switch to Jobs Tab
         ↓
JOBS TAB
├─ Bottom Sheet: ❌ HIDDEN (respects tab context)
├─ Job Details: ❌ NOT SHOWN
└─ Navigation: Switch back to Home
         ↓
HOME TAB
├─ Bottom Sheet: ✅ RE-APPEARS (restored)
├─ Job Details: ✅ DISPLAYED
└─ State: ✅ PRESERVED
```

## 🛠️ Bottom Sheet Monitoring System

```
┌─────────────────────────────────────────┐
│  Bottom Sheet Monitoring Timer          │
│  Runs every 2 seconds                   │
└──────────────┬──────────────────────────┘
               ↓
        Check Conditions:
               ↓
    ┌──────────────────────┐
    │ _currentIndex == 0?  │ ← Must be on Home Tab
    └──────────┬───────────┘
               ↓ YES
    ┌──────────────────────┐
    │  _hasActiveJob?      │ ← Must have active job
    └──────────┬───────────┘
               ↓ YES
    ┌──────────────────────┐
    │ Status NOT completed │ ← Job must be active
    │  or cancelled?       │
    └──────────┬───────────┘
               ↓ YES
    ┌──────────────────────┐
    │ Sheet not expanded?  │
    └──────────┬───────────┘
               ↓ YES
    ┌──────────────────────┐
    │ → EXPAND SHEET! 📌   │ ← Auto-expand
    └──────────────────────┘
```

## ✅ Fixed Condition Comparison

### ❌ BEFORE (BUGGY):
```dart
!['completed', 'cancelled', 'invoice_paid'].contains(status)
```
**Problem:** Sheet disappeared when invoice paid!

### ✅ AFTER (FIXED):
```dart
!['completed', 'cancelled'].contains(status)
```
**Solution:** Sheet stays visible through payment!

## 🎭 User Experience Flow

```
┌─────────────────────────────────────────┐
│   1. Customer Requests Service          │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   2. Mechanic Accepts Job               │
│      ├─ Bottom Sheet Appears ✅         │
│      └─ Shows: Customer info, location  │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   3. Mechanic Sends Invoice             │
│      ├─ Bottom Sheet Still Visible ✅   │
│      └─ Shows: "Waiting for payment"    │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   4. Customer Pays Invoice              │
│      ├─ Bottom Sheet STAYS VISIBLE ✅   │ ← FIX APPLIED HERE!
│      ├─ Status: "Payment Received"      │
│      └─ QR Scanner Button Enabled       │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   5. Mechanic Performs Service          │
│      ├─ Bottom Sheet Still Visible ✅   │
│      └─ Shows: Job tracking, timer      │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   6. Mechanic Scans Customer QR         │
│      ├─ Job Marked Complete             │
│      └─ Bottom Sheet Disappears ❌      │
└───────────────┬─────────────────────────┘
                ↓
┌─────────────────────────────────────────┐
│   7. Success! Back to Normal Dashboard  │
└─────────────────────────────────────────┘
```

## 🐛 Bug Details

### What Was Wrong?
The condition `!['completed', 'cancelled', 'invoice_paid'].contains(status)` 
caused the bottom sheet to hide as soon as payment was received.

### Why Was This Bad?
Mechanics still need to:
- See job details after payment
- Access customer contact info
- Track service progress
- Scan QR code to complete job

### How Was It Fixed?
Removed `'invoice_paid'` from the exclusion list, so the sheet only hides
when job is actually `'completed'` or `'cancelled'`.

## 📍 Code Locations

1. **Main Visibility Logic** (Lines 1048-1056)
   - Controls when bottom sheet renders in UI tree
   - Checks: Home tab + Active job + Not completed/cancelled

2. **Monitoring Logic** (Lines 198-206)
   - Ensures sheet stays expanded during active job
   - Runs every 2 seconds
   - Respects home tab and job status

3. **Job Restoration** (Lines 776-830)
   - Restores active job when app resumes
   - Automatically expands sheet after 300ms
   - Handles state persistence

## 🎉 Result

✅ Bottom sheet now correctly shows throughout entire service lifecycle
✅ Only hides when job is truly complete or cancelled
✅ Mechanics can track jobs from acceptance to completion
✅ No premature hiding during payment phase

**Status:** READY FOR PRODUCTION
**Date:** October 16, 2025
