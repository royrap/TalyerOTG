# 🚨 QUICK FIX CARD

## Your 3 Errors:
```
❌ Service request not found
❌ PGRST116: 0 rows returned  
❌ Shop isolation violation
```

## Fix in 3 Steps:

### 1️⃣ **FIX RLS** (5 minutes)
```sql
-- File: FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql
-- Open: Supabase Dashboard → SQL Editor
-- Action: Copy file → Paste → Run
-- Check: ✅ RLS policies relaxed
```

### 2️⃣ **ASSIGN MECHANIC** (2 minutes)
```sql
-- File: ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql
-- Open: Supabase Dashboard → SQL Editor
-- Action: Copy file → Paste → Run
-- Check: ✅ Mechanic assigned to shop
```

### 3️⃣ **RESTART APP** (1 minute)
```powershell
flutter run
```

## Test:
1. **Customer:** Create request → Select MechAid supply
2. **Mechanic:** Should see popup ✅
3. **Mechanic:** Click Accept ✅
4. **Result:** Request assigned ✅

## Files to Deploy:
- ✅ `FIX_RLS_POLICIES_BLOCKING_REQUESTS.sql` ← **MOST IMPORTANT**
- ✅ `ASSIGN_MECHANIC_TO_MECHAIDSUPPLY.sql`
- ✅ `flutter run`

## Total Time: ~10 minutes

---

**Need details?** See `DEPLOYMENT_CHECKLIST_FINAL.md`

**Need help?** See `RLS_FIX_URGENT_GUIDE.md`
