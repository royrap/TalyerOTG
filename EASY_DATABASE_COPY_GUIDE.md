# 💾 ROADAID - EASY DATABASE COPY GUIDE
**Paano i-copy ang database from MAIN to BACKUP**

---

## 📊 **YOUR DATABASES:**

### **MAIN DATABASE** (Source)
- Your current working database

### **BACKUP DATABASE** (Target)
```
URL: https://bfmfaczzwxquuirinjdo.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmbWZhY3p6d3hxdXVpcmluamRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MjA1MzksImV4cCI6MjA3NDk5NjUzOX0.PPL9nX7eRisyYjTofO2vbHUci-ID-t4YRAedbKtX92E

Supabase Client Code:
import { createClient } from '@supabase/supabase-js'
const supabaseUrl = 'https://bfmfaczzwxquuirinjdo.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
const supabase = createClient(supabaseUrl, supabaseKey)
```

---

## 🚀 **METHOD 1: EASIEST - Using Supabase CLI (RECOMMENDED)**

### **Step 1: Install Supabase CLI**
```powershell
# Install Supabase CLI (one-time only)
npm install -g supabase

# OR using Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### **Step 2: Login to Supabase**
```powershell
supabase login
```

### **Step 3: Link to MAIN Database**
```powershell
# Get your project ref from dashboard URL
# Example: if URL is https://abc123.supabase.co, ref is "abc123"

supabase link --project-ref YOUR_MAIN_PROJECT_REF
```

### **Step 4: Export from MAIN Database**
```powershell
# Export schema and data
supabase db dump -f roadaid_backup.sql --data-only

# OR export everything (schema + data)
supabase db dump -f roadaid_complete.sql
```

### **Step 5: Import to BACKUP Database**
```powershell
# Link to BACKUP database
supabase link --project-ref bfmfaczzwxquuirinjdo

# Import the dump
psql -h db.bfmfaczzwxquuirinjdo.supabase.co \
     -U postgres \
     -d postgres \
     -f roadaid_backup.sql
```

---

## 📦 **METHOD 2: Using Supabase Dashboard (NO CODING)**

### **From MAIN Database:**

1. **Open Supabase Dashboard** → Your MAIN project
2. **Go to Database** → **Backups**
3. **Click "Start a backup"**
4. **Wait for backup to complete** (5-10 minutes)
5. **Click "Download"** button
6. **Save file as:** `roadaid_backup_2025_10_03.sql`

### **To BACKUP Database:**

1. **Open Supabase Dashboard** → BACKUP project
   - URL: https://app.supabase.com/project/bfmfaczzwxquuirinjdo
2. **Go to SQL Editor**
3. **Click "New Query"**
4. **Open downloaded backup file** in text editor
5. **Copy all contents**
6. **Paste into SQL Editor**
7. **Click "Run"**
8. **Wait for completion** ✅

---

## 🔧 **METHOD 3: Manual SQL Export (For Small Databases)**

### **Step 1: Run in MAIN Database**
```sql
-- Copy this SQL and run in MAIN database
-- It will generate INSERT statements

-- For user_profiles table
SELECT 
    'INSERT INTO public.user_profiles VALUES (' ||
    quote_literal(id::text) || '::uuid, ' ||
    quote_literal(email) || ', ' ||
    quote_literal(display_name) || ', ' ||
    COALESCE(quote_literal(phone_number), 'NULL') || ', ' ||
    COALESCE(quote_literal(address), 'NULL') || ', ' ||
    quote_literal(user_type) || ', ' ||
    'DEFAULT, DEFAULT, NULL, NULL, NULL, ' ||
    'DEFAULT, DEFAULT, DEFAULT, NULL, NULL, ' ||
    'DEFAULT, DEFAULT, DEFAULT, DEFAULT' ||
    ');'
FROM public.user_profiles;

-- Repeat for each table...
```

### **Step 2: Copy Results to BACKUP**
- Copy all generated INSERT statements
- Run them in BACKUP database SQL Editor

---

## ⚡ **METHOD 4: Quick Copy with pg_dump (FASTEST)**

### **Step 1: Get Connection Strings**

**MAIN Database:**
```
Host: db.YOUR_MAIN_REF.supabase.co
Database: postgres
User: postgres
Password: YOUR_PASSWORD
Port: 5432
```

**BACKUP Database:**
```
Host: db.bfmfaczzwxquuirinjdo.supabase.co
Database: postgres
User: postgres
Password: YOUR_BACKUP_PASSWORD
Port: 5432
```

### **Step 2: Export from MAIN**
```powershell
pg_dump -h db.YOUR_MAIN_REF.supabase.co \
        -U postgres \
        -d postgres \
        -f roadaid_backup.sql \
        --clean --if-exists
```

### **Step 3: Import to BACKUP**
```powershell
psql -h db.bfmfaczzwxquuirinjdo.supabase.co \
     -U postgres \
     -d postgres \
     -f roadaid_backup.sql
```

---

## 📋 **TABLES TO COPY (38 Tables Total)**

### **Core Tables (10):**
✅ user_profiles  
✅ shops  
✅ mechanics  
✅ shop_mechanics  
✅ shop_services  
✅ service_requests  
✅ vehicles  
✅ service_categories  
✅ system_settings  
✅ app_versions

### **Financial Tables (7):**
✅ invoices  
✅ payments  
✅ paymongo_webhook_events  
✅ cash_payment_verifications  
✅ earnings  
✅ platform_statistics  
✅ reported_issues

### **Communication (8):**
✅ messages  
✅ notifications  
✅ notification_templates  
✅ user_notification_preferences  
✅ notification_delivery_log  
✅ do_not_disturb_settings  
✅ email_notifications  
✅ platform_announcements

### **Tracking & History (7):**
✅ service_request_status_log  
✅ request_broadcasts  
✅ mechanic_job_history  
✅ customer_job_history  
✅ audit_logs  
✅ account_security_logs  
✅ progress_photos

### **Reviews & Quality (3):**
✅ reviews  
✅ service_phase_tracking  
✅ business_permits

### **Admin (3):**
✅ admin_users  
✅ admin_activity_logs  
✅ document_verifications

---

## 🔄 **AUTOMATIC SYNC SETUP (Optional)**

### **Option 1: Supabase Replication**
```sql
-- Enable replication from MAIN to BACKUP
-- Run this in your MAIN database

CREATE PUBLICATION roadaid_backup FOR ALL TABLES;

-- Then in BACKUP database:
CREATE SUBSCRIPTION roadaid_backup_sub 
CONNECTION 'host=db.YOUR_MAIN_REF.supabase.co dbname=postgres user=postgres password=YOUR_PASSWORD'
PUBLICATION roadaid_backup;
```

### **Option 2: Scheduled Backup Script**
```javascript
// backup-cron.js - Run daily via GitHub Actions or Vercel Cron
import { createClient } from '@supabase/supabase-js'

const mainDb = createClient(MAIN_URL, MAIN_KEY)
const backupDb = createClient(
  'https://bfmfaczzwxquuirinjdo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
)

async function syncTable(tableName) {
  const { data } = await mainDb.from(tableName).select('*')
  await backupDb.from(tableName).upsert(data)
  console.log(`✅ Synced ${tableName}`)
}

// Run daily
const tables = ['user_profiles', 'shops', 'mechanics', ...]
for (const table of tables) {
  await syncTable(table)
}
```

---

## ✅ **VERIFICATION STEPS**

### **After copying, verify in BACKUP database:**

```sql
-- Check table counts
SELECT 
    schemaname,
    tablename,
    (SELECT COUNT(*) FROM public.user_profiles) as user_count,
    (SELECT COUNT(*) FROM public.shops) as shop_count,
    (SELECT COUNT(*) FROM public.mechanics) as mechanic_count,
    (SELECT COUNT(*) FROM public.service_requests) as request_count,
    (SELECT COUNT(*) FROM public.invoices) as invoice_count
FROM pg_tables
WHERE schemaname = 'public'
LIMIT 1;

-- Verify all tables exist
SELECT COUNT(*) as total_tables
FROM pg_tables
WHERE schemaname = 'public';
-- Should return 38 or more

-- Check if data matches
SELECT 
    'Main DB has: ' || (SELECT COUNT(*) FROM public.user_profiles) || ' users' as info
UNION ALL
SELECT 
    'Backup should match' as info;
```

---

## 🎯 **RECOMMENDED APPROACH FOR YOU:**

### **EASIEST = Method 2 (Dashboard)**
1. ✅ No coding required
2. ✅ Visual interface
3. ✅ Automatic backup creation
4. ✅ Safe and reliable

### **FASTEST = Method 4 (pg_dump)**
1. ✅ One command export
2. ✅ One command import
3. ✅ Complete with indexes and constraints

### **BEST FOR PRODUCTION = Method 1 (CLI)**
1. ✅ Version controlled
2. ✅ Automated backups
3. ✅ Professional setup

---

## 🔐 **IMPORTANT SECURITY NOTES:**

⚠️ **NEVER commit these to Git:**
- Anon keys
- Service role keys
- Database passwords
- Connection strings

✅ **Use environment variables:**
```env
BACKUP_DB_URL=https://bfmfaczzwxquuirinjdo.supabase.co
BACKUP_DB_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 📞 **SUPPORT:**

Kung may problem, check:
1. ✅ Are both databases accessible?
2. ✅ Do you have admin access?
3. ✅ Is there enough storage space?
4. ✅ Are foreign keys enabled?

---

**Ready to start?** Subukan mo ang **Method 2 (Dashboard)** - pinaka-simple! 🚀
