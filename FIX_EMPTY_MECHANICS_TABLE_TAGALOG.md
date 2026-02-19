# 🔧 Ayusin ang Empty Mechanics Table

## ❗ Problema
Ang `mechanics` table ay walang laman, kaya hindi gumagana ang:
- Nearby requests
- Shop assignments
- Mechanic eligibility checks

## ✅ Solusyon (2 Steps)

### Step 1: I-populate ang Mechanics Table

**Sa Supabase SQL Editor, i-run ang dalawang files na ito in order:**

1. **Una:** `POPULATE_MECHANICS_TABLE.sql`
   - Ito ay mag-create ng entries sa `mechanics` table
   - Para sa lahat ng users na may `user_type = 'mechanic'`
   - Automatic sync sa `service_providers` at `mechanic_availability_status`

2. **Pangalawa:** `FIX_NUMERIC_OVERFLOW_AND_FK_ERRORS.sql`
   - Ito ay mag-fix ng distance calculation errors
   - At foreign key relationship issues

### Step 2: Verify

Sa Supabase SQL Editor, i-run ito para mag-check:

```sql
-- Check kung may laman na ang mechanics table
SELECT 
    m.id,
    up.email,
    CONCAT(up.first_name, ' ', up.last_name) as name,
    m.is_available,
    m.is_verified,
    m.status
FROM mechanics m
INNER JOIN user_profiles up ON m.user_id = up.id;
```

**Expected Result:**
- Dapat may makita kang rows (at least 1 mechanic)
- Bawat mechanic user ay dapat may entry

## 🎯 Kung Walang Mechanic Users Pa

Kung ang `user_profiles` table ay walang `user_type = 'mechanic'` users, kailangan mo munang mag-register ng mechanics sa app.

**Option A: Register via App**
1. Create account sa app
2. Select "Mechanic" as user type
3. Complete registration

**Option B: Convert Existing User to Mechanic (SQL)**

```sql
-- Convert specific user to mechanic
UPDATE user_profiles
SET user_type = 'mechanic'
WHERE email = 'your_email@example.com';

-- Then run POPULATE_MECHANICS_TABLE.sql
```

## 📊 After Population, Expected Data Flow

```
user_profiles (user_type = 'mechanic')
    ↓
mechanics (main profile)
    ↓
service_providers (for queries)
    ↓
mechanic_availability_status (real-time status)
    ↓
shop_mechanics (shop assignments)
```

## 🔍 Quick Diagnostic

I-run ito para makita ang current state:

```sql
-- Count mechanics in each table
SELECT 
    'user_profiles' as table_name,
    COUNT(*) as count
FROM user_profiles 
WHERE user_type = 'mechanic'

UNION ALL

SELECT 
    'mechanics',
    COUNT(*)
FROM mechanics

UNION ALL

SELECT 
    'service_providers',
    COUNT(*)
FROM service_providers sp
INNER JOIN user_profiles up ON sp.user_id = up.id
WHERE up.user_type = 'mechanic'

UNION ALL

SELECT 
    'mechanic_availability_status',
    COUNT(*)
FROM mechanic_availability_status

UNION ALL

SELECT 
    'shop_mechanics (active)',
    COUNT(*)
FROM shop_mechanics
WHERE is_active = true;
```

## ⚠️ Common Issues

### Issue 1: "Still empty after running script"
**Cause:** Walang mechanic users sa `user_profiles`
**Fix:** Register at least one mechanic via app, then run `POPULATE_MECHANICS_TABLE.sql` again

### Issue 2: "Foreign key violation error"
**Cause:** User ID doesn't exist in `user_profiles`
**Fix:** Make sure user exists first:
```sql
SELECT id, email FROM user_profiles WHERE user_type = 'mechanic';
```

### Issue 3: "Mechanics still can't see requests"
**Cause:** Missing RLS policies or availability status
**Fix:** Run both scripts completely, then restart Flutter app

## 🚀 Final Checklist

- [ ] Ran `POPULATE_MECHANICS_TABLE.sql` in Supabase
- [ ] Verified mechanics table has entries
- [ ] Ran `FIX_NUMERIC_OVERFLOW_AND_FK_ERRORS.sql`
- [ ] Restarted Flutter app: `flutter run`
- [ ] Tested login as mechanic
- [ ] Checked "Nearby Requests" tab - should see requests now
- [ ] No more "input is out of range" errors
- [ ] No more "relationship not found" errors

## 📞 Kung May Problema Pa

Share mo ang result ng diagnostic query:
```sql
SELECT * FROM user_profiles WHERE user_type = 'mechanic';
SELECT COUNT(*) FROM mechanics;
```

At ang error messages sa Flutter terminal.
