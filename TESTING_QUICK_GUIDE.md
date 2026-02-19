# 🧪 RoadAid Testing Quick Guide

**Date:** October 16, 2025  
**Purpose:** Quick reference for testing new implementations

---

## ✅ Quick Test Scenarios

### 1. Invoice Payment - Mobile 📱

**Test Steps:**
1. Open app on Android/iOS device
2. Navigate to Invoice tab
3. Select an unpaid invoice
4. Tap "Select Payment Method"
5. Choose "Online Payment"
6. **Expected:** Bottom sheet appears (not new screen)
7. **Expected:** PayMongo WebView loads in bottom sheet
8. Complete test payment
9. **Expected:** Bottom sheet closes, returns to invoice screen
10. **Expected:** Invoice status updates to "paid"

**Pass Criteria:**
- ✅ Bottom sheet is 90% screen height
- ✅ WebView loads correctly
- ✅ Can't swipe to dismiss during payment
- ✅ "Open in Browser" button works
- ✅ Payment completion detected automatically

---

### 2. Invoice Payment - Desktop 💻

**Test Steps:**
1. Open app in web browser (Chrome/Edge)
2. Navigate to Invoice section
3. Select an unpaid invoice
4. Click "Select Payment Method"
5. Choose "Online Payment"
6. **Expected:** Dialog appears in center of screen
7. **Expected:** "Open in Browser" button visible
8. Click "Open in Browser"
9. **Expected:** PayMongo opens in new tab
10. Complete payment in new tab
11. Return to app
12. **Expected:** Invoice status updates via real-time

**Pass Criteria:**
- ✅ Dialog is centered (70% width, 80% height)
- ✅ Shows "Open in Browser" prominently
- ✅ Web platform shows helpful message
- ✅ Can close dialog with X button
- ✅ Real-time update reflects payment status

---

### 3. Mechanic Bottom Sheet Visibility 🔧

**Test Steps:**
1. Login as mechanic
2. Accept a service request
3. **Expected:** Bottom sheet appears in Home tab
4. Tap "Jobs" tab
5. **Expected:** Bottom sheet disappears
6. Tap "Home" tab
7. **Expected:** Bottom sheet reappears
8. Tap "History" tab
9. **Expected:** Bottom sheet disappears
10. Tap "Home" tab
11. **Expected:** Bottom sheet reappears

**Pass Criteria:**
- ✅ Bottom sheet only visible in Home tab
- ✅ Disappears when switching tabs
- ✅ Reappears when returning to Home
- ✅ Toggle button works to minimize/expand
- ✅ Doesn't block navigation

---

### 4. Mechanic Polyline - Real-Time 🗺️

**Test Steps:**
1. Login as mechanic with active job
2. Go to Home tab
3. **Expected:** Map shows route to customer (red line)
4. Enable location services
5. Walk/drive 50+ meters in any direction
6. Wait 15 seconds
7. **Expected:** Polyline redraws automatically
8. **Expected:** Route updates to new path
9. **Expected:** Camera adjusts to show full route
10. Check route color
11. **Expected:** Solid red line (RoadAid brand color)

**Pass Criteria:**
- ✅ Polyline appears immediately
- ✅ Route follows actual roads (not straight line)
- ✅ Updates within 15 seconds of movement
- ✅ Camera auto-adjusts to show route
- ✅ Distance and ETA update automatically
- ✅ Fallback to dashed orange line if API fails

---

### 5. Customer Polyline - Real-Time 📍

**Test Steps:**
1. Login as customer with active service
2. Go to Home tab
3. **Expected:** Bottom sheet shows mechanic location
4. **Expected:** Map shows route from mechanic (red line)
5. Have mechanic move 50+ meters
6. Wait 10 seconds
7. **Expected:** Mechanic marker moves on map
8. **Expected:** Polyline redraws automatically
9. **Expected:** Distance counter updates
10. **Expected:** ETA updates

**Pass Criteria:**
- ✅ Mechanic location shows in real-time
- ✅ Polyline follows actual roads
- ✅ Updates within 10 seconds
- ✅ Distance recalculates automatically
- ✅ ETA recalculates automatically
- ✅ Map is draggable/zoomable

---

## 🚨 Common Issues & Solutions

### Issue: Bottom sheet doesn't appear on mobile

**Solution:**
- Check screen width: Must be <600px for mobile UI
- Verify `kIsWeb` is false (not running in browser)
- Check console for errors
- Ensure WebView dependencies installed

### Issue: Polyline is a straight line instead of road route

**Solution:**
- This is the fallback behavior (API failed)
- Check Google Maps API key in environment
- Check console for "❌ Error getting route" messages
- Verify Google Directions API is enabled
- Check API quota/billing

### Issue: Polyline doesn't update in real-time

**Solution:**
- Enable location permissions on device
- Check GPS is enabled
- Verify Supabase realtime is connected
- Check console for "📡 Received location data update"
- Move more than 10 meters to trigger update
- Wait 10-15 seconds for next update cycle

### Issue: Payment WebView shows blank screen

**Solution:**
- Check internet connection
- Verify PayMongo API key is valid
- Check checkout URL is HTTPS
- Clear app cache and restart
- Check WebView is enabled on device

### Issue: Desktop dialog doesn't show WebView

**Solution:**
- This is expected on web platform (WebView not supported)
- Use "Open in Browser" button instead
- Desktop app should show WebView correctly

---

## 📊 Verification Checklist

### Before Release:

#### Invoice Payment:
- [ ] Tested on Android device
- [ ] Tested on iOS device  
- [ ] Tested on desktop browser (Chrome)
- [ ] Tested on desktop browser (Edge)
- [ ] Mobile bottom sheet appears correctly
- [ ] Desktop dialog appears correctly
- [ ] Payment completion detected
- [ ] External browser fallback works
- [ ] Real-time status updates work

#### Mechanic Bottom Sheet:
- [ ] Appears in Home tab
- [ ] Disappears in other tabs
- [ ] Toggle button works
- [ ] Job details display correctly
- [ ] Customer info loads
- [ ] Call button works
- [ ] History button works
- [ ] Invoice generation works
- [ ] QR scanning works

#### Polylines:
- [ ] Mechanic side shows route
- [ ] Customer side shows route
- [ ] Routes use actual roads (not straight)
- [ ] Real-time updates work (mechanic side)
- [ ] Real-time updates work (customer side)
- [ ] Distance calculates correctly
- [ ] ETA calculates correctly
- [ ] Camera auto-adjusts
- [ ] Fallback route works
- [ ] Map gestures work (drag/zoom/rotate)

#### Cross-Platform:
- [ ] Works on Android 10+
- [ ] Works on iOS 13+
- [ ] Works on Chrome desktop
- [ ] Works on Edge desktop
- [ ] Works on Safari (iOS)
- [ ] Responsive layouts work
- [ ] Orientation changes handled

---

## 🎯 Performance Benchmarks

### Expected Performance:

| Metric | Target | Acceptable |
|--------|--------|------------|
| Bottom sheet open time | <500ms | <1s |
| WebView load time | <2s | <3s |
| Polyline draw time | <1s | <2s |
| Location update interval | 10-15s | <30s |
| Route recalculation | <2s | <5s |
| Payment completion detection | <3s | <10s |

### Monitor These:

1. **Network Requests:**
   - PayMongo API calls
   - Google Directions API calls
   - Supabase realtime messages

2. **GPS Accuracy:**
   - Should be <20m for polylines
   - Should be <50m for markers

3. **Battery Usage:**
   - Real-time tracking should use <5% battery/hour
   - Background location should be minimal

---

## 🔧 Debug Commands

### Check Real-Time Connection:
```dart
print('🔗 Supabase realtime connected: ${SupabaseService.client.realtime.connectedAt}');
```

### Monitor Location Updates:
```dart
print('📍 Location update: lat=$latitude, lng=$longitude, accuracy=$accuracy');
```

### Track Polyline Changes:
```dart
print('🗺️ Polyline points: ${routePoints.length}, color: ${polyline.color}');
```

### Verify Payment Status:
```dart
print('💳 Payment status: $status, invoice_id: $invoiceId');
```

---

## 📱 Test Devices Recommended

### Minimum Test Matrix:

1. **Android:**
   - Android 10+ (Samsung/Pixel)
   - Screen size: 5.5" - 6.5"
   
2. **iOS:**
   - iOS 13+ (iPhone 8 or newer)
   - Screen size: 4.7" - 6.7"

3. **Desktop:**
   - Chrome (Windows/Mac)
   - Resolution: 1920x1080

4. **Tablet (Optional):**
   - iPad Pro (should use desktop UI)
   - Android tablet (should use mobile UI if <600px width)

---

## ✅ Final Sign-Off

### Testing Complete When:

- [ ] All test scenarios pass
- [ ] No console errors
- [ ] Performance within targets
- [ ] Works on all required platforms
- [ ] User acceptance testing passed
- [ ] Documentation reviewed
- [ ] Code review completed

**Tester:** _______________  
**Date:** _______________  
**Sign-Off:** _______________

---

*End of Testing Guide*
