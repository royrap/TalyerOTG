# 🔧 CUSTOM SERVICE TROUBLESHOOTING GUIDE

## 🎯 Issue: Custom services saved but not showing in UI

Based on your console logs, custom services are being saved successfully:
```
✅ Custom service insert result: [{id: 5c469c26-b9b8-4d30-b99f-02a4d045bb50...
✅ Custom service insert result: [{id: 979c1d04-92c8-4273-b8bd-7d526a605190...
```

## 🔍 DEBUGGING STEPS

### Step 1: Check Database Fix Deployment
**IMPORTANT**: First ensure you've run the `CUSTOM_SERVICE_AVAILABILITY_MATRIX_FIX.sql` script in Supabase SQL Editor.

### Step 2: Use Debug Button
1. Open your Flutter app
2. Go to **Manage Services** screen  
3. Click the **🐛 bug icon** in the top-right corner
4. Check console output for:
   - Raw database entries
   - Query results with joins
   - Service count information

### Step 3: Check Console Logs
When loading services, look for:
```
🔍 Loading services...
📊 Loaded services count: X
📋 Services data: [detailed service data]
🎨 Building service card for: [service info]
```

### Step 4: Test Adding New Custom Service
1. Click **+ (Add Service)**
2. Select **Custom Service**
3. Enter name and description
4. Watch console for:
   ```
   🔧 Saving custom service: [name], description: [desc], price: [price]
   🏪 Shop ID: [shop-id]
   📦 Service data to insert: [full data]
   ✅ Custom service insert result: [result]
   🔄 Forcing reload of services...
   ```

## 🎯 POTENTIAL ISSUES & SOLUTIONS

### Issue 1: Database Constraints ❌
**Symptom**: Error about availability matrix constraints
**Solution**: Run `CUSTOM_SERVICE_AVAILABILITY_MATRIX_FIX.sql` in Supabase

### Issue 2: Wrong Shop ID ❌  
**Symptom**: Services being saved to wrong shop or shop ID is null
**Solution**: Check user authentication and shop ownership

### Issue 3: Query Issues ❌
**Symptom**: Services in database but query returns empty
**Solution**: Check if `getShopServices()` is using correct shop_id filter

### Issue 4: UI Refresh Issues ❌
**Symptom**: Services exist but UI doesn't update  
**Solution**: Force reload after save operations

## 🛠️ DEBUGGING ACTIONS TAKEN

✅ **Updated Flutter Code**: 
- Fixed `getShopServices()` to query `shop_services` table instead of `provider_services`
- Added comprehensive debugging logs
- Added debug button for manual testing
- Enhanced service loading and display logic

✅ **Enhanced Error Handling**:
- Better error messages
- Force reload after service operations
- Detailed console logging

⚠️ **Database Fix**: 
- Created `CUSTOM_SERVICE_AVAILABILITY_MATRIX_FIX.sql`
- **Status**: Needs deployment in Supabase

## 🚀 NEXT ACTIONS

1. **Deploy Database Fix**: Run the SQL script in Supabase SQL Editor
2. **Hot Restart**: Restart your Flutter app completely (not just hot reload)
3. **Use Debug Tools**: Click the bug icon to see what's actually in the database
4. **Test Step by Step**: Add one custom service and watch console logs

## 📊 EXPECTED RESULTS

After following these steps, you should see:
- ✅ Custom services appear in the manage services list
- ✅ Correct service count (including custom services)
- ✅ Ability to edit/delete custom services
- ✅ Proper service card display with "CUSTOM" badges

## 🆘 IF STILL NOT WORKING

If services still don't show after these steps:
1. Check the console output from the debug button
2. Verify your user ID and shop ID are correct
3. Check if there are any RLS (Row Level Security) policies blocking access
4. Ensure you're logged in as the correct shop owner

Let me know what the debug button shows! 🐛
