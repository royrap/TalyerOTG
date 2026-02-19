# 🔍 COMPLETE TROUBLESHOOTING GUIDE - Dashboard No Data

## 📋 STEP-BY-STEP DEBUGGING

### **STEP 1: Run DEBUG SQL Script**

1. Open Supabase SQL Editor
2. Run `DEBUG_WHY_NO_DATA.sql`
3. **COPY ALL RESULTS** and send to me

This will show:
- ✅ Current UTC vs Manila time
- ✅ All completed jobs with dates
- ✅ Your shop info
- ✅ Mechanics in your shop
- ✅ Whether jobs match "today" filter

### **STEP 2: Hot Restart with Debug Logs**

I added debug logging to your Flutter code. Now:

1. **Stop the app** (press `q` in terminal)
2. **Run again:** `flutter run`
3. **Open Shop Owner Dashboard**
4. **Look at terminal output** for these lines:

```
🔍 DEBUG: Loading earnings for period: today
🔍 DEBUG: Start date (UTC): 2025-10-06 00:00:00.000Z
🔍 DEBUG: Shop ID: <your-shop-id>
🔍 DEBUG: Earnings data received: {...}
🔍 DEBUG: Total revenue: 515.0
🔍 DEBUG: Shop earnings: 103.0
🔍 DEBUG: Mechanic earnings: 386.25
```

**COPY the debug output** and send to me!

### **STEP 3: Check for Possible Issues**

## 🔍 **Possibility 1: Shop ID Mismatch**

**Problem:** Jobs might be assigned to different shop_id than your logged-in shop.

**How to check:**
- Run the SQL script and compare:
  - Your shop_id from "YOUR SHOP INFO" section
  - shop_id in "ALL COMPLETED JOBS" section
- If they don't match → Jobs belong to different shop!

**Fix:** Assign jobs to correct shop_id in database.

---

## 🔍 **Possibility 2: Date is Actually Tomorrow/Yesterday**

**Problem:** Job completed "tomorrow" in UTC but "today" in Manila time.

**Example:**
- Manila: Oct 6, 2025 at 6:00 PM (UTC+8)
- UTC: Oct 6, 2025 at 10:00 AM
- Filter "today UTC": Oct 6 00:00 to Oct 7 00:00 ✅ (matches!)
- But if job was Oct 5 in UTC → won't show

**How to check:**
- Look at SQL results: `completed_date_utc` vs `completed_date_manila`
- Check `matches_today_filter` column

**Fix:** 
- Try switching dashboard to "Week" view
- Or complete a new test job right now

---

## 🔍 **Possibility 3: Jobs Not Linked to Mechanics**

**Problem:** Jobs completed but `assigned_mechanic_id` is NULL.

**How to check:**
- SQL results: Look at `assigned_mechanic_id` column
- If NULL → No mechanic assigned

**Fix:** Assign mechanic to jobs in database.

---

## 🔍 **Possibility 4: Mechanic Not in Shop**

**Problem:** Mechanic exists but not in `shop_mechanics` table.

**How to check:**
- Compare mechanic IDs in "MECHANICS IN SHOP" vs job's `assigned_mechanic_id`

**Fix:** Add mechanic to shop_mechanics table.

---

## 🔍 **Possibility 5: Data Service Not Returning Data**

**Problem:** Flutter query works but data service returns empty.

**How to check:**
- Look at debug logs in terminal
- Check: `Earnings data received: {}`
- If empty object → Query found no data

**Fix:** Check SQL script results to see why.

---

## 📱 **QUICK ACTIONS TO TRY NOW:**

### **Action 1: Try "Week" View**
1. In dashboard, switch from "Today" to "Week"
2. See if data appears
3. If yes → Date filtering issue

### **Action 2: Complete New Test Job**
1. Create and complete a test job RIGHT NOW
2. Check if it shows immediately
3. If yes → Old job has date issue

### **Action 3: Check Terminal Logs**
1. Look at your Flutter terminal
2. Find debug lines starting with `🔍 DEBUG:`
3. Copy all debug output
4. Send to me

---

## 📤 **WHAT TO SEND ME:**

Please provide:

1. ✅ **SQL Results** from `DEBUG_WHY_NO_DATA.sql`
   - Especially: "ALL COMPLETED JOBS" section
   - And: "YOUR SHOP INFO" section

2. ✅ **Flutter Debug Logs** from terminal
   - Lines starting with `🔍 DEBUG:`
   - Any error messages

3. ✅ **Screenshot** of dashboard showing no data

With these 3 things, I can pinpoint the EXACT problem! 🎯
