# 🔒 RLS Policy Analysis & Cleanup Recommendations

**Date:** October 7, 2025  
**Purpose:** Identify redundant, overly permissive, or conflicting RLS policies that should be removed and handled in backend logic instead.

---

## ⚠️ CRITICAL ISSUES - IMMEDIATE ACTION REQUIRED

### 1. **ALLOW_ALL Policies (SEVERE SECURITY RISK)**

These policies bypass all security and should be **REMOVED IMMEDIATELY**:

```sql
-- ❌ REMOVE THESE IMMEDIATELY
DROP POLICY "service_categories_allow_all" ON service_categories;
DROP POLICY "service_providers_allow_all" ON service_providers;
DROP POLICY "service_requests_allow_all" ON service_requests;
DROP POLICY "shops_allow_all" ON shops;
DROP POLICY "user_locations_allow_all" ON user_locations;
```

**Why?** These policies allow **ANYONE** (even unauthenticated users) to do **ANYTHING** to these tables. This is a **massive security hole**.

**Solution:** Remove these and rely on specific, scoped policies below them.

---

### 2. **Duplicate/Redundant Policies**

#### **service_requests table (7 policies doing same thing)**
```sql
-- Keep ONLY ONE comprehensive policy:
✅ KEEP: "service_request_access" (authenticated, covers all cases)

-- ❌ REMOVE these duplicates:
DROP POLICY "service_requests_allow_all" ON service_requests;
DROP POLICY "service_requests_invoice_view" ON service_requests;
DROP POLICY "service_requests_policy" ON service_requests;
DROP POLICY "shop_owners_view_their_requests" ON service_requests;
DROP POLICY "talyer_owners_view_all_requests" ON service_requests;
```

**Reason:** All these policies check the same conditions (customer_id, assigned_mechanic_id, shop owner). One comprehensive policy is sufficient and easier to maintain.

---

#### **shops table (9 policies - massive redundancy)**
```sql
-- Keep ONLY these 2:
✅ KEEP: "Anyone can view active shops" (SELECT for public)
✅ KEEP: "Shop owners can manage own shops" (consolidated ALL policy)

-- ❌ REMOVE these 7 duplicates:
DROP POLICY "shops_allow_all" ON shops;
DROP POLICY "Shop owners can create shops" ON shops;  -- Covered by ALL
DROP POLICY "Shop owners can delete own shops" ON shops;  -- Covered by ALL
DROP POLICY "Shop owners can update own shops" ON shops;  -- Covered by ALL
DROP POLICY "shop_owners_view_own_shop" ON shops;  -- Covered by ALL
DROP POLICY "shops_delete_owner" ON shops;  -- Duplicate
DROP POLICY "shops_insert_owner" ON shops;  -- Duplicate
DROP POLICY "shops_select_owner" ON shops;  -- Duplicate
DROP POLICY "shops_update_owner" ON shops;  -- Duplicate
DROP POLICY "talyer_owners_view_own_shop" ON shops;  -- Duplicate
```

**Consolidated Policy:**
```sql
-- This ONE policy replaces 8 others:
CREATE POLICY "shop_owners_full_access" ON shops
FOR ALL
TO authenticated
USING (owner_id = auth.uid() OR is_active = true)
WITH CHECK (owner_id = auth.uid());
```

---

#### **shop_services table (15 policies - extreme redundancy)**
```sql
-- Keep ONLY these 3:
✅ KEEP: "shop_owners_manage_own_services" (ALL for owners)
✅ KEEP: "customers_view_active_services" (SELECT for customers)
✅ KEEP: "anonymous_view_active_services" (SELECT for anon)

-- ❌ REMOVE these 12 duplicates:
DROP POLICY "customers_view_shop_specific_services" ON shop_services;  -- Duplicate of customers_view_active_services
DROP POLICY "mechanics_view_shop_services" ON shop_services;  -- Handle in backend
DROP POLICY "shop_owners_only_own_services" ON shop_services;  -- Duplicate
DROP POLICY "shop_services_delete_owner" ON shop_services;  -- Covered by ALL
DROP POLICY "shop_services_insert_owner" ON shop_services;  -- Covered by ALL
DROP POLICY "shop_services_isolated_delete" ON shop_services;  -- Duplicate
DROP POLICY "shop_services_isolated_insert" ON shop_services;  -- Duplicate
DROP POLICY "shop_services_isolated_select" ON shop_services;  -- Duplicate
DROP POLICY "shop_services_isolated_update" ON shop_services;  -- Duplicate
DROP POLICY "shop_services_select_owner" ON shop_services;  -- Covered by ALL
DROP POLICY "shop_services_update_owner" ON shop_services;  -- Covered by ALL
```

---

#### **shop_mechanics table (7 policies)**
```sql
-- Keep ONLY these 2:
✅ KEEP: "Shop owners can manage their mechanics" (ALL for owners)
✅ KEEP: "Mechanics can view their shop assignments" (SELECT for mechanics)

-- ❌ REMOVE these 5 duplicates:
DROP POLICY "Admins have full access to shop_mechanics" ON shop_mechanics;  -- Handle in backend
DROP POLICY "mechanics_can_view_assignments" ON shop_mechanics;  -- Duplicate
DROP POLICY "shop_owners_view_shop_mechanics" ON shop_mechanics;  -- Covered by ALL
DROP POLICY "talyer_owners_view_shop_mechanics" ON shop_mechanics;  -- Duplicate
```

---

#### **mechanic_availability_status table (4 policies)**
```sql
-- Keep ONLY these 2:
✅ KEEP: "Mechanics can manage their own availability" (ALL)
✅ KEEP: "Everyone can view mechanic availability for routing" (SELECT - needed for shop selection)

-- ❌ REMOVE these 2 duplicates:
DROP POLICY "Shop owners can view their mechanics availability" ON mechanic_availability_status;  -- Covered by "Everyone can view"
DROP POLICY "mechanics_manage_own_status" ON mechanic_availability_status;  -- Duplicate
```

---

#### **invoices table (4 policies)**
```sql
-- Keep ONLY ONE comprehensive policy:
✅ KEEP: "invoices_customer_view" (covers all parties)

-- ❌ REMOVE these 3 duplicates:
DROP POLICY "invoices_insert_party" ON invoices;
DROP POLICY "invoices_select_party" ON invoices;
DROP POLICY "invoices_update_party" ON invoices;
```

**Consolidated:**
```sql
CREATE POLICY "invoices_access" ON invoices
FOR ALL
TO authenticated
USING (
  customer_id = auth.uid() OR 
  talyer_owner_id = auth.uid() OR 
  mechanic_id = auth.uid() OR
  provider_id = auth.uid()
)
WITH CHECK (
  customer_id = auth.uid() OR 
  provider_id = auth.uid()
);
```

---

#### **service_providers table (7 policies - major duplication)**
```sql
-- Keep ONLY these 2:
✅ KEEP: "Anyone can view verified service providers" (SELECT for public)
✅ KEEP: "service_providers_access_policy" (ALL for authenticated owners/admins)

-- ❌ REMOVE these 5 duplicates:
DROP POLICY "service_providers_allow_all" ON service_providers;  -- SECURITY RISK
DROP POLICY "Service providers can insert own profile" ON service_providers;  -- Covered by access_policy
DROP POLICY "Service providers can update own profile" ON service_providers;  -- Covered by access_policy
DROP POLICY "Service providers can view own profile" ON service_providers;  -- Covered by access_policy
DROP POLICY "service_providers_invoice_view" ON service_providers;  -- Covered by access_policy
```

---

#### **talyer_owner_verifications table (8 policies - testing leftover)**
```sql
-- Keep ONLY these 2:
✅ KEEP: "verifications_admin_manage" (admins full access)
✅ KEEP: "verifications_insert_owner" (owners can submit)

-- ❌ REMOVE these 6 (testing artifacts):
DROP POLICY "verifications_admin_status_update" ON talyer_owner_verifications;  -- Covered by admin_manage
DROP POLICY "verifications_select_self" ON talyer_owner_verifications;  -- Should be in backend
DROP POLICY "verifications_update_owner" ON talyer_owner_verifications;  -- Should be in backend (only admins update status)
DROP POLICY "working_insert_all" ON talyer_owner_verifications;  -- TESTING LEFTOVER - REMOVE
DROP POLICY "working_select_all" ON talyer_owner_verifications;  -- TESTING LEFTOVER - REMOVE
DROP POLICY "working_update_all" ON talyer_owner_verifications;  -- TESTING LEFTOVER - REMOVE
```

---

### 3. **Policies That Should Be Backend Logic**

These policies are too complex or frequently changing - move to backend:

#### **admin_activity_logs (5 policies - should be backend)**
```sql
-- ❌ REMOVE ALL, handle in backend:
DROP POLICY "Admins can insert activity logs" ON admin_activity_logs;
DROP POLICY "Admins can view audit logs" ON admin_activity_logs;
DROP POLICY "Admins can view their own activity logs" ON admin_activity_logs;
DROP POLICY "Super admins can view all activity logs" ON admin_activity_logs;
DROP POLICY "admin_activity_logs_admin_only" ON admin_activity_logs;

-- Replace with ONE simple policy:
CREATE POLICY "admin_logs_backend_only" ON admin_activity_logs
FOR ALL
TO authenticated
USING (
  auth.uid() IN (
    SELECT id FROM user_profiles 
    WHERE user_type IN ('admin', 'super_admin')
  )
);
```

**Why?** Admin logging should be controlled by backend code, not RLS. Too many edge cases.

---

#### **inspection_reports (4 policies - backend is better)**
```sql
-- ❌ REMOVE duplicates:
DROP POLICY "Customers can view inspection reports" ON inspection_reports;  -- Duplicate
DROP POLICY "inspection_reports_customer_view" ON inspection_reports;  -- Duplicate

-- Keep ONLY:
✅ KEEP: "Service providers can manage inspection reports" (ALL for providers)
```

**Better:** Handle customer access in backend (check service_requests relationship).

---

#### **job_completion_codes (5 policies - overly complex)**
```sql
-- ❌ REMOVE, handle in backend:
DROP POLICY "Customers can insert their own QR codes" ON job_completion_codes;
DROP POLICY "Customers can manage completion codes" ON job_completion_codes;
DROP POLICY "Customers can view their own QR codes" ON job_completion_codes;
DROP POLICY "Service providers can update QR codes for verification" ON job_completion_codes;

-- Keep ONLY:
✅ KEEP: "job_completion_codes_customer" (ALL for customers - simplified)
```

**Why?** QR code generation/validation has business logic (expiration, one-time use) that belongs in backend, not RLS.

---

#### **request_routing (3 policies - backend job)**
```sql
-- ❌ REMOVE ALL, this is purely backend logic:
DROP POLICY "System can manage request routing" ON request_routing;
DROP POLICY "Users can view routing for their requests" ON request_routing;
DROP POLICY "mechanic_can_view_own_routings" ON request_routing;

-- Replace with service-level access in backend
```

**Why?** Request routing is complex business logic (shop-based vs broadcast, mechanic availability) that changes frequently. Don't lock it in RLS.

---

### 4. **Service Role Policies (Unnecessary)**

```sql
-- ❌ REMOVE (service role bypasses RLS anyway):
DROP POLICY "simple_service_role" ON user_profiles;
```

**Why?** The `service_role` key already bypasses ALL RLS policies. This policy does nothing.

---

## 📋 RECOMMENDED POLICY CLEANUP SQL

```sql
-- ============================================
-- PHASE 1: REMOVE CRITICAL SECURITY RISKS
-- ============================================

-- Remove ALLOW_ALL policies (IMMEDIATE)
DROP POLICY IF EXISTS "service_categories_allow_all" ON service_categories;
DROP POLICY IF EXISTS "service_providers_allow_all" ON service_providers;
DROP POLICY IF EXISTS "service_requests_allow_all" ON service_requests;
DROP POLICY IF EXISTS "shops_allow_all" ON shops;
DROP POLICY IF EXISTS "user_locations_allow_all" ON user_locations;

-- ============================================
-- PHASE 2: REMOVE DUPLICATES
-- ============================================

-- service_requests: Keep "service_request_access" only
DROP POLICY IF EXISTS "service_requests_invoice_view" ON service_requests;
DROP POLICY IF EXISTS "service_requests_policy" ON service_requests;
DROP POLICY IF EXISTS "shop_owners_view_their_requests" ON service_requests;
DROP POLICY IF EXISTS "talyer_owners_view_all_requests" ON service_requests;

-- shops: Keep 2 policies (view active, owners manage)
DROP POLICY IF EXISTS "Shop owners can create shops" ON shops;
DROP POLICY IF EXISTS "Shop owners can delete own shops" ON shops;
DROP POLICY IF EXISTS "Shop owners can update own shops" ON shops;
DROP POLICY IF EXISTS "shop_owners_view_own_shop" ON shops;
DROP POLICY IF EXISTS "shops_delete_owner" ON shops;
DROP POLICY IF EXISTS "shops_insert_owner" ON shops;
DROP POLICY IF EXISTS "shops_select_owner" ON shops;
DROP POLICY IF EXISTS "shops_update_owner" ON shops;
DROP POLICY IF EXISTS "talyer_owners_view_own_shop" ON shops;

-- shop_services: Keep 3 policies (owners manage, customers view, anon view)
DROP POLICY IF EXISTS "customers_view_shop_specific_services" ON shop_services;
DROP POLICY IF EXISTS "mechanics_view_shop_services" ON shop_services;
DROP POLICY IF EXISTS "shop_owners_only_own_services" ON shop_services;
DROP POLICY IF EXISTS "shop_services_delete_owner" ON shop_services;
DROP POLICY IF EXISTS "shop_services_insert_owner" ON shop_services;
DROP POLICY IF EXISTS "shop_services_isolated_delete" ON shop_services;
DROP POLICY IF EXISTS "shop_services_isolated_insert" ON shop_services;
DROP POLICY IF EXISTS "shop_services_isolated_select" ON shop_services;
DROP POLICY IF EXISTS "shop_services_isolated_update" ON shop_services;
DROP POLICY IF EXISTS "shop_services_select_owner" ON shop_services;
DROP POLICY IF EXISTS "shop_services_update_owner" ON shop_services;

-- shop_mechanics: Keep 2 policies (owners manage, mechanics view)
DROP POLICY IF EXISTS "Admins have full access to shop_mechanics" ON shop_mechanics;
DROP POLICY IF EXISTS "mechanics_can_view_assignments" ON shop_mechanics;
DROP POLICY IF EXISTS "shop_owners_view_shop_mechanics" ON shop_mechanics;
DROP POLICY IF EXISTS "talyer_owners_view_shop_mechanics" ON shop_mechanics;

-- mechanic_availability_status: Keep 2 policies
DROP POLICY IF EXISTS "Shop owners can view their mechanics availability" ON mechanic_availability_status;
DROP POLICY IF EXISTS "mechanics_manage_own_status" ON mechanic_availability_status;

-- invoices: Consolidate to 1 policy
DROP POLICY IF EXISTS "invoices_insert_party" ON invoices;
DROP POLICY IF EXISTS "invoices_select_party" ON invoices;
DROP POLICY IF EXISTS "invoices_update_party" ON invoices;

-- service_providers: Keep 2 policies
DROP POLICY IF EXISTS "Service providers can insert own profile" ON service_providers;
DROP POLICY IF EXISTS "Service providers can update own profile" ON service_providers;
DROP POLICY IF EXISTS "Service providers can view own profile" ON service_providers;
DROP POLICY IF EXISTS "service_providers_invoice_view" ON service_providers;

-- talyer_owner_verifications: Remove testing artifacts
DROP POLICY IF EXISTS "verifications_admin_status_update" ON talyer_owner_verifications;
DROP POLICY IF EXISTS "verifications_select_self" ON talyer_owner_verifications;
DROP POLICY IF EXISTS "verifications_update_owner" ON talyer_owner_verifications;
DROP POLICY IF EXISTS "working_insert_all" ON talyer_owner_verifications;
DROP POLICY IF EXISTS "working_select_all" ON talyer_owner_verifications;
DROP POLICY IF EXISTS "working_update_all" ON talyer_owner_verifications;

-- ============================================
-- PHASE 3: MOVE TO BACKEND LOGIC
-- ============================================

-- admin_activity_logs: Remove all, handle in backend
DROP POLICY IF EXISTS "Admins can insert activity logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Admins can view audit logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Admins can view their own activity logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Super admins can view all activity logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "admin_activity_logs_admin_only" ON admin_activity_logs;

-- inspection_reports: Remove duplicates
DROP POLICY IF EXISTS "Customers can view inspection reports" ON inspection_reports;
DROP POLICY IF EXISTS "inspection_reports_customer_view" ON inspection_reports;

-- job_completion_codes: Simplify to 1 policy
DROP POLICY IF EXISTS "Customers can insert their own QR codes" ON job_completion_codes;
DROP POLICY IF EXISTS "Customers can manage completion codes" ON job_completion_codes;
DROP POLICY IF EXISTS "Customers can view their own QR codes" ON job_completion_codes;
DROP POLICY IF EXISTS "Service providers can update QR codes for verification" ON job_completion_codes;

-- request_routing: Remove all (backend only)
DROP POLICY IF EXISTS "System can manage request routing" ON request_routing;
DROP POLICY IF EXISTS "Users can view routing for their requests" ON request_routing;
DROP POLICY IF EXISTS "mechanic_can_view_own_routings" ON request_routing;

-- user_profiles: Remove service role policy (unnecessary)
DROP POLICY IF EXISTS "simple_service_role" ON user_profiles;

-- ============================================
-- PHASE 4: CREATE CONSOLIDATED POLICIES
-- ============================================

-- Simplified admin logs (one policy replaces 5)
CREATE POLICY "admin_logs_access" ON admin_activity_logs
FOR ALL TO authenticated
USING (
  auth.uid() IN (
    SELECT id FROM user_profiles 
    WHERE user_type IN ('admin', 'super_admin')
  )
);

-- Consolidated invoice policy
CREATE POLICY "invoices_comprehensive_access" ON invoices
FOR ALL TO authenticated
USING (
  customer_id = auth.uid() OR 
  talyer_owner_id = auth.uid() OR 
  mechanic_id = auth.uid() OR
  provider_id = auth.uid()
)
WITH CHECK (
  customer_id = auth.uid() OR 
  provider_id = auth.uid()
);
```

---

## 📊 SUMMARY

### Before Cleanup:
- **Total Policies:** ~120+
- **Duplicate Policies:** ~40
- **Security Risks:** 5 allow_all policies
- **Overly Complex:** ~15 policies

### After Cleanup:
- **Total Policies:** ~60-70 (50% reduction)
- **Duplicate Policies:** 0
- **Security Risks:** 0
- **Complex Policies:** Move to backend

### Benefits:
✅ **50% fewer policies** = easier maintenance  
✅ **No security holes** = proper access control  
✅ **Better performance** = simpler policy evaluation  
✅ **Clearer ownership** = one policy per use case  
✅ **Backend flexibility** = business logic where it belongs  

---

## 🎯 CRITICAL TABLES FOR SHOP-BASED REQUEST SYSTEM

For your new Grab/JoyRide-style feature, ensure these policies remain:

### ✅ Keep These Policies:

```sql
-- service_requests: Comprehensive access
✅ "service_request_access" - Customers, mechanics, shop owners

-- shops: Public view + owner manage
✅ "Anyone can view active shops" - For shop selection UI
✅ "Shop owners can manage own shops" - Owner CRUD

-- shop_mechanics: Owner manage + mechanic view
✅ "Shop owners can manage their mechanics" - Assignment
✅ "Mechanics can view their shop assignments" - See own shops

-- mechanic_availability_status: Everyone view + mechanic manage
✅ "Everyone can view mechanic availability for routing" - CRITICAL for shop selection
✅ "Mechanics can manage their own availability" - Status updates

-- notifications: System insert + user view/update
✅ "System can insert notifications" - For request notifications
✅ "Users can view own notifications" - Mechanic sees requests
✅ "Users can update own notifications" - Mark as read
```

---

## 🚀 NEXT STEPS

1. **Backup database** before running cleanup
2. **Run PHASE 1** (remove allow_all) IMMEDIATELY
3. **Test app functionality** after each phase
4. **Run PHASE 2-3** (remove duplicates, move to backend)
5. **Run PHASE 4** (create consolidated policies)
6. **Update backend code** to handle moved logic
7. **Re-test all features** especially:
   - Shop selection
   - Mechanic assignments
   - Request notifications
   - Invoice generation

---

## ⚠️ WARNING

**DO NOT run all DROP statements at once without testing!**

Run each phase separately and test your app between phases. Some features may break if they depend on specific policies.

**Priority Order:**
1. Remove allow_all policies (CRITICAL)
2. Remove obvious duplicates (shop_services, shops)
3. Test thoroughly
4. Remove backend-logic policies
5. Create consolidated policies
6. Final testing
