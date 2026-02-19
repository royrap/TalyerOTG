# 🔧 SQL Syntax Error Fix - Hide Closed Shops

## ❌ Errors Encountered

### Error 1: Reserved Keyword
```
ERROR: 42601: syntax error at or near "current_time"
LINE 28: current_time := check_time::TIME;
```

### Error 2: Function Return Type Mismatch
```
ERROR: 42P13: cannot change return type of existing function
DETAIL: Row type defined by OUT parameters is different.
HINT: Use DROP FUNCTION get_nearby_shops(numeric,numeric,numeric) first.
```

## 🐛 Problems

**Problem 1:** The error occurred because **`current_time` is a reserved keyword in PostgreSQL**. We cannot use it as a variable name in PL/pgSQL functions.

**Problem 2:** The function `get_nearby_shops` already existed with a different return structure. We added a new column `is_open` to the return type, but PostgreSQL won't let you change the return type with `CREATE OR REPLACE` - you must drop the function first.

### Reserved Keywords in PostgreSQL:
- `current_time` - Returns current time
- `current_date` - Returns current date
- `current_timestamp` - Returns current timestamp

## ✅ Solution

**Changed variable names from reserved keywords to descriptive names:**

### Before (❌ Error):
```sql
DECLARE
    current_day TEXT;
    current_time TIME;  -- ERROR: Reserved keyword!
```

### After (✅ Fixed):
```sql
DECLARE
    day_of_week TEXT;
    time_of_day TIME;  -- No conflict!
```

## 🔄 Changes Made

### File: `HIDE_CLOSED_SHOPS_IMPLEMENTATION.sql`

**Fix 1 - Changed variables:**
1. `current_day` → `day_of_week`
2. `current_time` → `time_of_day`

**Updated in 2 places:**
1. Function `is_shop_open()` declaration
2. Test DO block

**Fix 2 - Added DROP statement:**
```sql
DROP FUNCTION IF EXISTS get_nearby_shops(NUMERIC, NUMERIC, NUMERIC);
```
This drops the existing function before recreating it with the new return type (added `is_open` column)

## ✅ Fixed Code

```sql
CREATE OR REPLACE FUNCTION is_shop_open(
    shop_business_hours JSONB,
    check_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS BOOLEAN AS $$
DECLARE
    day_of_week TEXT;    -- ✅ Not a reserved keyword
    time_of_day TIME;    -- ✅ Not a reserved keyword
    day_hours JSONB;
    open_time TEXT;
    close_time TEXT;
BEGIN
    -- Get current day of week (lowercase)
    day_of_week := LOWER(TO_CHAR(check_time, 'Day'));
    day_of_week := TRIM(day_of_week);
    
    -- Get current time
    time_of_day := check_time::TIME;
    
    -- ... rest of function logic
    
    -- Check if current time is within business hours
    RETURN time_of_day >= open_time::TIME 
       AND time_of_day <= close_time::TIME;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

## 🚀 Ready to Deploy

**Status:** ✅ **FIXED - Ready to run**

### Deployment Steps:
1. Open Supabase SQL Editor
2. Copy the **fixed** `HIDE_CLOSED_SHOPS_IMPLEMENTATION.sql`
3. Run the script
4. Should execute without errors now!

## 📝 Lesson Learned

**Always avoid PostgreSQL reserved keywords for variable names:**

### Reserved Keywords to Avoid:
- `current_time`
- `current_date`
- `current_timestamp`
- `current_user`
- `session_user`
- `user`
- `date`
- `time`
- `timestamp`

### Good Alternative Names:
- `day_of_week`, `time_of_day`, `date_value`
- `timestamp_value`, `user_id`, `username`
- `check_date`, `check_time`, `check_timestamp`

## ✅ Verification

**Test the fix:**
```sql
-- Should work without syntax errors
SELECT is_shop_open(
    '{"monday": {"open": "08:00", "close": "18:00"}}'::JSONB,
    NOW()
);
```

---

**Error Fixed!** ✅ Run the updated SQL script now!
