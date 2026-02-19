# Complete RLS Revert Guide

## Status: Ready to Revert All RLS Modifications

Gusto mo alisin lahat ng RLS modifications at balik sa original code bago mo sinabi "check mo mg rls".

---

## Step 1: DROP All RPC Functions (Supabase)

**Action**: I-run ang `DROP_ALL_RPC_FUNCTIONS.sql` sa Supabase SQL Editor

Ito ay mag-aalis ng:
- ✅ `get_shop_mechanics_for_owner()` 
- ✅ `get_mechanic_job_history()`
- ✅ `get_talyer_owner_dashboard_stats()`
- ✅ `get_talyer_owner_recent_requests(integer)`
- ✅ `get_talyer_owner_mechanic_stats()`
- ✅ `get_talyer_owner_customers()`
- ✅ `get_talyer_owner_earnings_breakdown()`
- ✅ `test_dashboard_stats(uuid)`

---

## Step 2: Revert Flutter Files

Hindi ko makita ang EXACT original code bago ang RLS modifications kasi maraming changes na nangyari. 

**Files na need i-revert:**

### 1. `lib/services/talyer_owner_service.dart` (Line ~1772)
**Current (RPC-based):**
```dart
Future<List<Map<String, dynamic>>> getShopMechanics() async {
  // Uses RPC: get_shop_mechanics_for_owner()
  final mechanicsData = await _supabase
      .rpc('get_shop_mechanics_for_owner')
      .select();
  // ... complex mapping code ...
}
```

**Original (Direct Query - NEED TO RESTORE):**
```dart
Future<List<Map<String, dynamic>>> getShopMechanics() async {
  // Direct query with JOIN
  final mechanicsData = await _supabase
      .from('shop_mechanics')
      .select('''
        *,
        user_profiles!shop_mechanics_mechanic_id_fkey(
          id,
          first_name,
          last_name,
          email,
          phone_number,
          profile_image_url
        )
      ''')
      .eq('shop_id', shopId)
      .eq('is_active', true);
  
  // Simple data access
}
```

---

### 2. `lib/services/mechanic_history_service.dart` (Line ~13)
**Current (RPC-based):**
```dart
Future<List<MechanicJobHistory>> getMechanicJobHistory({...}) async {
  // Debug logging (REMOVE)
  print('🔧 MechanicHistoryService.getMechanicJobHistory()');
  print('   📝 Logged in as: ${userProfile?['first_name']}...');
  
  // Uses RPC
  final result = await _supabase.rpc('get_mechanic_job_history');
  
  // Complex nested mapping
  final mappedResults = (result as List).map((mjh) {
    return {
      'user_profiles': {
        'first_name': mjh['customer_first_name'],
        // ...
      },
    };
  }).toList();
}
```

**Original (Direct Query - NEED TO RESTORE):**
```dart
Future<List<MechanicJobHistory>> getMechanicJobHistory({...}) async {
  // Simple direct query with JOIN
  final results = await _supabase
      .from('mechanic_job_history')
      .select('''
        *,
        user_profiles!mechanic_job_history_customer_id_fkey(
          first_name,
          last_name,
          phone_number,
          profile_image_url,
          email
        ),
        service_requests!mechanic_job_history_service_request_id_fkey(*),
        shops!mechanic_job_history_shop_id_fkey(*)
      ''')
      .eq('mechanic_id', user.id);
  
  // Direct data access: results[0]['user_profiles']['first_name']
}
```

---

### 3. `lib/services/talyer_owner_data_service.dart` (Line ~946)
**Current (RPC-based):**
```dart
Future<Map<String, dynamic>> getDashboardOverview({...}) async {
  // Multiple RPC calls
  final results = await Future.wait([
    _supabase.rpc('get_talyer_owner_dashboard_stats').select(),
    _supabase.rpc('get_talyer_owner_recent_requests', params: {'limit_count': 10}).select(),
    _supabase.rpc('get_talyer_owner_mechanic_stats').select(),
    _supabase.rpc('get_talyer_owner_earnings_breakdown').select(),
    getShopMechanics(shopId),
    getShopNotifications(shopId: shopId, unreadOnly: true, limit: 5),
  ]);
  
  // Complex result mapping
}
```

**Original (Direct Queries - NEED TO RESTORE):**
```dart
Future<Map<String, dynamic>> getDashboardOverview({...}) async {
  // Multiple parallel direct queries
  final results = await Future.wait([
    // Get earnings
    _supabase
        .from('service_requests')
        .select('shop_earnings')
        .eq('shop_id', shopId)
        .eq('status', 'completed'),
    
    // Get job counts
    _supabase
        .from('service_requests')
        .select('id', count: CountOption.exact)
        .eq('shop_id', shopId),
    
    // Get mechanics
    _supabase
        .from('shop_mechanics')
        .select('id', count: CountOption.exact)
        .eq('shop_id', shopId),
    
    // ... more queries ...
  ]);
  
  // Simple data access
}
```

---

### 4. `lib/talyer_owner/shop_owner_dashboard_screen.dart` (Line ~1044)
**Current (Nested Access):**
```dart
// Handle nested structure from RPC
final mechanicProfile = mechanic['mechanic'] ?? mechanic;
Text('${mechanicProfile['first_name']} ${mechanicProfile['last_name']}')
```

**Original (Direct Access - NEED TO RESTORE):**
```dart
// Direct access from query
Text('${mechanic['first_name']} ${mechanic['last_name']}')
```

---

## Problem: Hindi Ko Alam ang EXACT Original Code

**Issue**: Maraming modifications na nangyari, at wala akong access sa git history o original version ng code bago mo sinabi "check mo mg rls".

**Options:**

### Option A: Manual Revert (Recommended)
1. Check mo ang git history kung meron
   ```powershell
   git log --oneline --all
   git show <commit-hash-before-RLS>
   ```

2. O kaya i-check mo ang backup files kung meron ka

3. Sabihan mo ako kung ano ang exact original implementation para ma-revert ko correctly

### Option B: Reconstruct Original (Risky)
I'll guess the original implementation based on standard Supabase patterns, pero pwedeng mali kasi maraming ways to implement:

```dart
// Example guess - pero verify mo!
final mechanicsData = await _supabase
    .from('shop_mechanics')
    .select('''
      id,
      shop_id,
      mechanic_id,
      is_active,
      is_available,
      specialties,
      user_profiles!shop_mechanics_mechanic_id_fkey(
        id,
        first_name,
        last_name,
        email,
        phone_number,
        profile_image_url
      )
    ''')
    .eq('shop_id', shopId)
    .eq('is_active', true);
```

### Option C: Fresh Start (Nuclear Option)
- Delete entire folder
- Fresh clone/copy from backup
- Start over

---

## After Revert: Expected Issues

⚠️ **Warning**: Pag nag-revert tayo, babalik ang ORIGINAL RLS PROBLEMS:

1. **Dashboard ₱0 Earnings** - RLS blocking queries
2. **"null null" Mechanic Names** - RLS blocking nested data  
3. **RLS Infinite Recursion** - Error 42P17
4. **Empty Mechanic List** - RLS policies causing issues

**Reason why we used RPC in the first place**: RLS policies were causing infinite recursion when querying `user_profiles` → `service_requests` → `user_profiles`.

---

## Next Steps

**Tell me:**
1. ✅ Run `DROP_ALL_RPC_FUNCTIONS.sql` sa Supabase - READY
2. ❓ Ano ang EXACT original code for the 4 Flutter files?
   - Check git history?
   - Check backup?
   - Or reconstruct based on patterns?

**Or:**
- Kung gusto mo, fix the ROOT CAUSE (RLS policies) instead of reverting
- The RPC solution worked, pero may new issues (missing columns, constraints)
- Maybe better to fix those issues than revert everything?

---

## Summary

**Current State**: RPC-based architecture (working but complex)
**Target State**: Original direct queries (simple but RLS issues)
**Blocker**: Need original code to revert accurately

**Recommendation**: Before reverting, consider:
- Why did we switch to RPC? (RLS infinite recursion)
- Will reverting solve or just bring back old problems?
- Maybe better to fix the RPC issues (missing columns, constraints)?

**Your call**: 
- Revert and deal with RLS again? 
- Or fix the current RPC issues?

Sabihan mo lang ano gusto mo gawin! 👍
