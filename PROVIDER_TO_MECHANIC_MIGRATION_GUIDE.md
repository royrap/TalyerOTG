# Provider to Mechanic Migration Guide

## 📋 Overview

This guide explains how to migrate the RoadAid system from using the `service_providers` table to directly using mechanics from the `user_profiles` table.

### Current Problem
- `service_requests.provider_id` currently references `service_providers` table
- This creates unnecessary complexity with an intermediary table
- Provider references are displayed throughout the UI

### Solution
- Change `provider_id` foreign key to reference `user_profiles` (mechanics directly)
- Remove all provider-related UI displays
- Simplify the data flow to use mechanic information directly

---

## 🔧 Step 1: Database Migration

### Run the SQL Script

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to SQL Editor

2. **Execute Migration Script**
   - Open the file: `MIGRATION_PROVIDER_TO_MECHANIC.sql`
   - Copy the entire contents
   - Paste into SQL Editor
   - Click "Run" or press Ctrl+Enter

3. **Verify Success**
   - Check that the success message appears
   - Run the verification queries at the bottom of the script
   - Confirm `provider_id` now references `user_profiles` table

### What the Migration Does

```sql
-- Before:
service_requests.provider_id → service_providers.id → user_profiles.id

-- After:
service_requests.provider_id → user_profiles.id (DIRECT)
```

**Changes Made:**
- ✅ Drops old foreign key: `service_requests_provider_id_fkey → service_providers`
- ✅ Adds new foreign key: `service_requests_provider_id_fkey → user_profiles`
- ✅ Creates performance index on `provider_id`
- ✅ Backs up data to `service_requests_backup_20251002`

---

## 📱 Step 2: Flutter Code Changes

### Files That Need Updates (70+ occurrences found)

Below are the key files using `provider_id` that need to be reviewed and updated:

#### **High Priority Files**

1. **lib/services/talyer_owner_service.dart** (14 occurrences)
   - Lines: 643, 653, 885, 902, 976, 2013, 2039, 2072, 2079, 2081, 2097, 2152, 2179, 3233
   - **Action**: Replace provider lookups with direct mechanic queries

2. **lib/services/invoice_service.dart** (13 occurrences)
   - Lines: 90, 194, 439, 478, 576, 640, 671, 925, 1012, 1038
   - **Action**: Update invoice generation to use mechanic_id instead of provider_id

3. **lib/services/customer_history_service.dart** (7 occurrences)
   - Lines: 42, 46, 107, 313, 317, 756
   - **Action**: Change queries to fetch mechanic data directly

4. **lib/services/paymongo_service.dart** (8 occurrences)
   - Lines: 568, 577, 724, 731, 801
   - **Action**: Update payment records to use mechanic_id

5. **lib/services/comprehensive_data_service.dart** (10 occurrences)
   - Lines: 149, 184, 283, 343, 413, 438, 467, 485
   - **Action**: Remove provider_id references, use mechanic_id

#### **Medium Priority Files**

6. **lib/main.dart** (3 occurrences)
7. **lib/mechanic/enhanced_invoice_generation_screen.dart** (3 occurrences)
8. **lib/customer/cash_payment_screen.dart** (1 occurrence)
9. **lib/talyer_owner/job_monitoring_screen.dart** (3 occurrences)
10. **lib/talyer_owner/incoming_requests_screen.dart** (5 occurrences)

#### **Low Priority Files (Debug/Test)**

11. **lib/debug/payment_status_debug.dart**
12. **test/messaging_diagnosis_test.dart**

---

## 🎨 Step 3: Remove Provider UI References

### UI Components to Update

Search for and remove/update these UI elements:

#### **Search Patterns**
```dart
// Find these patterns in your codebase:
"Provider:"
"Provider ID:"
"Service Provider"
"provider['"]
"Provider Name"
"${provider"
```

#### **Common UI Locations**

1. **Request Details Screens**
   - Remove provider name displays
   - Replace with mechanic name
   - Update avatar/profile image sources

2. **History/Job Lists**
   - Remove provider company name
   - Show mechanic first_name + last_name instead

3. **Invoice Screens**
   - Remove provider business information
   - Show mechanic information only

4. **Monitoring/Tracking Screens**
   - Remove provider status indicators
   - Use mechanic availability status

---

## 🔄 Step 4: Code Update Patterns

### Pattern 1: Query Changes

**Before:**
```dart
final response = await supabase
    .from('service_requests')
    .select('''
        *,
        provider:service_providers!service_requests_provider_id_fkey(
            id,
            company_name,
            user:user_profiles(first_name, last_name)
        )
    ''')
    .eq('provider_id', providerId);
```

**After:**
```dart
final response = await supabase
    .from('service_requests')
    .select('''
        *,
        mechanic:user_profiles!service_requests_provider_id_fkey(
            id,
            first_name,
            last_name,
            email,
            phone_number
        )
    ''')
    .eq('provider_id', mechanicId);
```

### Pattern 2: Data Access Changes

**Before:**
```dart
final providerName = serviceRequest['provider']?['company_name'] ?? 'Unknown';
final mechanicName = serviceRequest['provider']?['user']?['first_name'] ?? 'Unknown';
```

**After:**
```dart
final mechanicName = 
    '${serviceRequest['mechanic']?['first_name'] ?? ''} ${serviceRequest['mechanic']?['last_name'] ?? ''}'.trim();
```

### Pattern 3: UI Display Changes

**Before:**
```dart
Text('Provider: ${provider['company_name']}')
Text('Mechanic: ${provider['user']['first_name']}')
```

**After:**
```dart
Text('Mechanic: ${mechanic['first_name']} ${mechanic['last_name']}')
```

---

## ✅ Step 5: Verification Checklist

### Database Verification

- [ ] Migration script executed successfully
- [ ] Foreign key constraint points to `user_profiles`
- [ ] Existing `provider_id` values are valid mechanic IDs
- [ ] No orphaned records (provider_id pointing to non-existent users)

### Code Verification

- [ ] All `provider_id` queries updated to use mechanic data
- [ ] No more references to `service_providers` table in service_requests queries
- [ ] Invoice generation uses mechanic information
- [ ] Payment processing uses mechanic_id correctly

### UI Verification

- [ ] No "Provider" labels visible in customer app
- [ ] No "Provider" labels visible in mechanic app
- [ ] No "Provider" labels visible in talyer owner dashboard
- [ ] All displays show "Mechanic" instead
- [ ] Mechanic names display correctly (first + last name)

### Functional Testing

- [ ] Create new service request → mechanic assigned correctly
- [ ] Accept request as mechanic → provider_id set correctly
- [ ] Generate invoice → mechanic information correct
- [ ] Process payment → mechanic receives payment
- [ ] View job history → mechanic name displays correctly
- [ ] Track real-time location → mechanic tracking works
- [ ] Complete job → mechanic completion recorded correctly

---

## 🔥 Quick Reference: Key Changes

| Component | Old Behavior | New Behavior |
|-----------|-------------|--------------|
| **Foreign Key** | `provider_id → service_providers.id` | `provider_id → user_profiles.id` |
| **Query Join** | `provider:service_providers!fkey` | `mechanic:user_profiles!fkey` |
| **Display Name** | `provider.company_name` | `mechanic.first_name + last_name` |
| **UI Label** | "Provider:" | "Mechanic:" |
| **Invoice** | Provider business info | Mechanic personal info |
| **Payment** | To provider entity | To mechanic user |

---

## 📊 Impact Analysis

### Tables Affected
- ✅ `service_requests` - Foreign key constraint changed
- ⚠️ `service_providers` - May become unused (consider deprecation)
- ⚠️ `invoices` - Already has `mechanic_id`, but also has `provider_id`
- ⚠️ `payments` - Already has correct structure

### Files Affected
- **70+ files** contain `provider_id` references
- **15+ core service files** need updates
- **10+ UI screens** need provider label removal
- **5+ test files** may need updates

### Migration Effort
- **Database**: 5 minutes (run SQL script)
- **Code Updates**: 2-4 hours (update queries and logic)
- **UI Updates**: 1-2 hours (remove provider displays)
- **Testing**: 2-3 hours (verify all flows work)
- **Total**: ~1 day of development work

---

## 🚨 Common Issues & Solutions

### Issue 1: Foreign Key Violation
**Error**: `violates foreign key constraint`
**Solution**: Ensure all existing `provider_id` values are valid mechanic user IDs in `user_profiles`

```sql
-- Check for invalid provider_id values
SELECT sr.id, sr.provider_id
FROM service_requests sr
LEFT JOIN user_profiles up ON sr.provider_id = up.id
WHERE sr.provider_id IS NOT NULL AND up.id IS NULL;
```

### Issue 2: Query Returns Null
**Error**: Mechanic data is null after query
**Solution**: Update the foreign key reference name in `.select()` queries

```dart
// Wrong:
.select('*, provider:service_providers(*)') 

// Correct:
.select('*, mechanic:user_profiles!service_requests_provider_id_fkey(*)')
```

### Issue 3: UI Shows "Provider" Label
**Error**: Old "Provider:" labels still visible
**Solution**: Search entire codebase for hardcoded "Provider" strings

```bash
# Search command:
grep -r "Provider:" lib/
grep -r "'Provider'" lib/
grep -r '"Provider"' lib/
```

---

## 📝 Notes

- The `service_providers` table may still exist for backward compatibility
- Consider marking `service_providers` as deprecated
- Future feature: May want to completely remove `service_providers` table
- Keep backup table `service_requests_backup_20251002` for 30 days

---

## ✨ Benefits After Migration

1. **Simpler Data Model**: Direct relationship between requests and mechanics
2. **Fewer Joins**: Queries are faster with one less join
3. **Cleaner UI**: No confusion between provider and mechanic
4. **Better Performance**: Reduced query complexity
5. **Easier Maintenance**: Fewer tables to manage

---

## 🎯 Next Steps

1. ✅ Run database migration script
2. ⏳ Update Flutter service files (in progress)
3. ⏳ Remove provider UI references
4. ⏳ Test all service request flows
5. ⏳ Deploy to production

---

**Last Updated**: October 2, 2025  
**Status**: Database migration ready, code updates in progress  
**Estimated Completion**: 1 day
