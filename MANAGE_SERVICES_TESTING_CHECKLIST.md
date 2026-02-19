# ✅ MANAGE SERVICES - TESTING CHECKLIST

## 🗄️ DATABASE SETUP (DO THIS FIRST!)

### Step 1: Run SQL Script
- [ ] Open Supabase Dashboard (https://app.supabase.com)
- [ ] Go to your project
- [ ] Click "SQL Editor" sa left sidebar
- [ ] Create new query
- [ ] Copy-paste lahat ng content ng `SHOP_SERVICES_DATABASE_SETUP.sql`
- [ ] Click "Run" button
- [ ] Verify na may success messages sa result

### Step 2: Verify RLS Policies
```sql
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'shop_services';
```
**Expected Results (dapat may 5):**
- [ ] "Shop owners can view their shop services" (SELECT)
- [ ] "Shop owners can insert their shop services" (INSERT)
- [ ] "Shop owners can update their shop services" (UPDATE)
- [ ] "Shop owners can delete their shop services" (DELETE)
- [ ] "Customers can view active shop services" (SELECT)

### Step 3: Check Indexes
```sql
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'shop_services';
```
**Expected Results:**
- [ ] idx_shop_services_shop_id
- [ ] idx_shop_services_is_active
- [ ] idx_shop_services_service_name
- [ ] idx_shop_services_is_custom
- [ ] idx_shop_services_shop_active

### Step 4: Verify Table Structure
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'shop_services'
ORDER BY ordinal_position;
```
**Must Have These Columns:**
- [ ] id (uuid)
- [ ] shop_id (uuid)
- [ ] service_name (text)
- [ ] description (text)
- [ ] base_price (numeric)
- [ ] is_custom (boolean)
- [ ] is_active (boolean)
- [ ] created_at (timestamp)
- [ ] updated_at (timestamp)

---

## 📱 APP TESTING

### Pre-Test Requirements
- [ ] Database setup complete ✅
- [ ] RLS policies verified ✅
- [ ] Flutter app compiled successfully
- [ ] You have a talyer_owner account
- [ ] That account has a shop in `shops` table

### Test 1: Open Screen
- [ ] Login as talyer_owner
- [ ] Navigate to dashboard
- [ ] Find "Manage Services" button/menu
- [ ] Tap to open
- [ ] Screen loads without errors
- [ ] Shows "No services added yet" (if first time)

### Test 2: Add Service
- [ ] Tap the red "+ Add Service" FAB button
- [ ] Dialog opens
- [ ] Shows info text: "Add your custom service with just the basics"
- [ ] Has 3 fields:
  - [ ] Service Name * (with hint text)
  - [ ] Description (optional)
  - [ ] Price (₱) * (with hint text)
- [ ] Has "* Required fields" text
- [ ] Has Cancel and Add Service buttons

### Test 3: Validation
**Try adding without name:**
- [ ] Leave Service Name empty
- [ ] Enter price: 1500
- [ ] Tap "Add Service"
- [ ] Should show error: "Service name is required" ❌

**Try adding without price:**
- [ ] Enter Service Name: "Test Service"
- [ ] Leave Price empty
- [ ] Tap "Add Service"
- [ ] Should show error: "Price is required" ❌

**Try invalid price:**
- [ ] Enter Service Name: "Test Service"
- [ ] Enter Price: "abc" or "-100"
- [ ] Tap "Add Service"
- [ ] Should show error: "Enter a valid price" ❌

### Test 4: Successful Add
- [ ] Enter Service Name: "Oil Change"
- [ ] Enter Description: "Full synthetic oil with filter"
- [ ] Enter Price: 1500
- [ ] Tap "Add Service"
- [ ] Dialog closes
- [ ] Shows green snackbar: "Service added successfully" ✅
- [ ] Service appears in list
- [ ] Card shows:
  - [ ] Red wrench icon
  - [ ] Service name "Oil Change"
  - [ ] Green price badge "₱1500"
  - [ ] Gray description box
  - [ ] Blue edit button
  - [ ] Red delete button

### Test 5: Database Verification
**Check kung naka-save sa database:**
```sql
SELECT * FROM shop_services 
WHERE shop_id IN (
    SELECT id FROM shops 
    WHERE owner_id = auth.uid()
)
ORDER BY created_at DESC
LIMIT 1;
```
**Verify:**
- [ ] service_name = "Oil Change"
- [ ] description = "Full synthetic oil with filter"
- [ ] base_price = 1500.00
- [ ] is_custom = true ✅
- [ ] is_active = true ✅
- [ ] created_at is recent
- [ ] updated_at is recent

### Test 6: Edit Service
- [ ] Tap blue EDIT icon on a service
- [ ] Dialog opens pre-filled with existing data
- [ ] Title says "Edit Service"
- [ ] Change price from 1500 to 2000
- [ ] Tap "Update"
- [ ] Dialog closes
- [ ] Shows green snackbar: "Service updated successfully"
- [ ] Price in list now shows ₱2000

**Verify in database:**
```sql
SELECT service_name, base_price, updated_at 
FROM shop_services 
WHERE service_name = 'Oil Change';
```
- [ ] base_price = 2000.00 ✅
- [ ] updated_at is recent ✅

### Test 7: Search Function
**Add more services first:**
- [ ] Add "Brake Repair" - ₱2500
- [ ] Add "Tire Rotation" - ₱800
- [ ] Add "Battery Test" - ₱300

**Test search:**
- [ ] Tap search bar
- [ ] Type "brake"
- [ ] Only "Brake Repair" shows ✅
- [ ] Type "tire"
- [ ] Only "Tire Rotation" shows ✅
- [ ] Clear search (X button)
- [ ] All services show again ✅

### Test 8: Delete Service
- [ ] Tap red DELETE icon on "Battery Test"
- [ ] Confirmation dialog appears
- [ ] Shows: "Are you sure you want to delete..."
- [ ] Tap "Cancel" first
- [ ] Nothing happens ✅
- [ ] Tap DELETE icon again
- [ ] Tap "Delete" in dialog
- [ ] Service disappears from list
- [ ] Shows green snackbar: "Service deleted successfully"

**Verify in database:**
```sql
SELECT * FROM shop_services 
WHERE service_name = 'Battery Test';
```
- [ ] Should return 0 rows ✅

### Test 9: Refresh
- [ ] Tap refresh icon in top right
- [ ] Loading indicator shows briefly
- [ ] Services reload from database
- [ ] All active services still there ✅

### Test 10: Empty State
- [ ] Delete all services (or use fresh shop)
- [ ] Should show:
  - [ ] Large wrench icon
  - [ ] "No services added yet"
  - [ ] "Tap the + button below to add your first service"

---

## 🔒 SECURITY TESTING

### Test 11: RLS Security
**Create 2 shop owners:**
- Shop Owner A (you)
- Shop Owner B (test account)

**Test isolation:**
- [ ] Login as Shop Owner A
- [ ] Add service "Service A"
- [ ] Logout
- [ ] Login as Shop Owner B
- [ ] Open Manage Services
- [ ] Should NOT see "Service A" ✅
- [ ] Add service "Service B"
- [ ] Logout
- [ ] Login as Shop Owner A
- [ ] Should NOT see "Service B" ✅
- [ ] Should only see "Service A" ✅

### Test 12: Customer View
- [ ] Login as customer (not shop owner)
- [ ] Try to access Manage Services
- [ ] Should NOT be able to access ❌
- [ ] Or should show empty/error

---

## 🐛 ERROR HANDLING

### Test 13: Network Error
- [ ] Turn off internet/WiFi
- [ ] Try to add a service
- [ ] Should show error snackbar
- [ ] Turn on internet
- [ ] Try again
- [ ] Should work now ✅

### Test 14: Long Text
- [ ] Add service with very long name (100+ characters)
- [ ] Should still work
- [ ] Card should handle overflow properly
- [ ] Try very long description (500+ characters)
- [ ] Should truncate in list view

### Test 15: Special Characters
- [ ] Add service with name: "Oil & Filter Change (Premium)"
- [ ] Should work ✅
- [ ] Add service with emoji: "🔧 Repair Service"
- [ ] Should work ✅

---

## 📊 PERFORMANCE

### Test 16: Many Services
- [ ] Add 20+ services
- [ ] List should scroll smoothly
- [ ] Search should still be fast
- [ ] Loading should be quick

### Test 17: Rapid Actions
- [ ] Quickly add 3 services in a row
- [ ] All should save properly
- [ ] No duplicate IDs
- [ ] All show correct data

---

## 💯 FINAL VERIFICATION

### Code Quality
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] No console warnings
- [ ] Proper error handling
- [ ] Success messages show

### Database
- [ ] RLS policies working
- [ ] Indexes created
- [ ] Data saving correctly
- [ ] Timestamps updating
- [ ] Foreign keys valid

### UI/UX
- [ ] Forms are intuitive
- [ ] Buttons are responsive
- [ ] Messages are clear
- [ ] Colors are appropriate
- [ ] Icons make sense

### Functionality
- [ ] Add works ✅
- [ ] Edit works ✅
- [ ] Delete works ✅
- [ ] Search works ✅
- [ ] Refresh works ✅

---

## 📝 TEST RESULTS SUMMARY

**Date Tested:** _______________

**Tested By:** _______________

**Device/Platform:** _______________

### Results:
- Total Tests: 17
- Passed: _____
- Failed: _____
- Skipped: _____

### Issues Found:
1. _________________________________
2. _________________________________
3. _________________________________

### Notes:
_________________________________
_________________________________
_________________________________

---

## 🎯 ACCEPTANCE CRITERIA

### ✅ Must Pass ALL of These:
- [ ] Can add service with just name, description, price
- [ ] Service saves to database
- [ ] Service appears in list immediately
- [ ] Can edit service
- [ ] Changes save to database
- [ ] Can delete service with confirmation
- [ ] Search filters services correctly
- [ ] Only shop owner sees their services
- [ ] No compilation errors
- [ ] No runtime crashes

### If ANY of these fail:
1. Check database setup
2. Verify RLS policies
3. Check user has shop_id
4. Review error messages
5. Check console logs

---

## 🚀 DEPLOYMENT CHECKLIST

Before deploying to production:
- [ ] All tests passed ✅
- [ ] Database setup complete ✅
- [ ] RLS policies verified ✅
- [ ] Code reviewed ✅
- [ ] Documentation updated ✅
- [ ] Backup created ✅
- [ ] Test data removed ✅

---

## 📞 TROUBLESHOOTING QUICK REFERENCE

### "Error loading services"
→ Check RLS policies and shop_id

### "Cannot add service"
→ Verify user is talyer_owner with shop

### "Service not showing"
→ Check is_active flag and shop_id match

### "Delete not working"
→ Verify RLS DELETE policy exists

### Form validation not working
→ Check formKey.currentState!.validate()

---

**✅ TESTING COMPLETE!**

Kung lahat ng tests ay PASSED, ready na ang feature! 🎉

If may FAILED, review ang error messages at follow troubleshooting steps.
