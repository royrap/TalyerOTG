## 🔧 REMOVE TODAY'S EARNINGS & EMERGENCY BUTTON

### Files to modify:
1. lib/mechanic/angkas_mechanic_dashboard.dart
2. lib/mechanic/angkas_earnings_screen.dart

### Changes:

**angkas_mechanic_dashboard.dart:**
1. Remove Emergency button (lines 1516-1527)
2. Remove Today's Earnings display (lines 2317-2334)
3. Keep emergency flag display in request popup (this is different - shows if customer request is emergency)

**angkas_earnings_screen.dart:**
1. Remove todayEarnings variable and calculation (lines 114, 138, 174)

### ⚠️ IMPORTANT:
- DO NOT remove emergency flag from incoming_request_popup.dart - this shows if a CUSTOMER'S request is emergency
- Only remove mechanic's own "Emergency" action button

### To apply:
Run multi_replace operations to remove these specific sections.
