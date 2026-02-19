# RoadAid Email Deep Link Setup Guide

## Problem
When clicking the alternative link in password reset emails, it shows "localhost:3000 refused to connect" (ERR_CONNECTION_REFUSED).

## Root Cause
The `{{ .ConfirmationURL }}` variable in Supabase email templates uses the **Site URL** configuration. If this is set to `localhost:3000` or `http://localhost`, users will get connection errors.

## ✅ Solution: Configure Supabase Site URL

### Step 1: Update Supabase Site URL
1. Go to **Supabase Dashboard**
2. Navigate to **Authentication → URL Configuration**
3. Find **Site URL** field
4. Change from `http://localhost:3000` to: `roadaid://`

### Step 2: Keep Redirect URLs
Your existing redirect URLs are correct (keep them):
- `roadaid://reset-password`
- `roadaid://confirm-signup`
- `roadaid://email-change`
- `roadaid://confirm-email?code=xyz`
- `roadaid://login?email={{mechanic_email}}`
- `RoadAid://confirm-signup`
- `RoadAid://reset-password`
- `RoadAid://auth-callback`

### Step 3: Save and Test
1. Save the configuration
2. Send a test password reset email
3. Click the link - it should now open your app instead of localhost

## How It Works

### Email Template Deep Links
Your email templates use **two methods** to open the app:

**Method 1: Primary Button (Deep Link)**
```html
<a href="roadaid://reset-password?access_token={{ .Token }}">Reset Password in App</a>
```
This always uses the deep link scheme directly.

**Method 2: Alternative Link (ConfirmationURL)**
```html
<a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
```
This uses Supabase's generated URL based on your Site URL setting.

### What Happens When User Clicks

**Scenario A: User clicks primary button**
1. Opens deep link: `roadaid://reset-password?access_token=abc123`
2. Android handles the intent
3. Your Flutter app opens to password reset screen
4. ✅ Works correctly

**Scenario B: User clicks alternative link (CURRENT ISSUE)**
1. If Site URL = `http://localhost:3000`
   - Link becomes: `http://localhost:3000/reset-password?token=abc123`
   - Browser tries to connect to localhost
   - ❌ Connection refused error

2. If Site URL = `roadaid://` (CORRECT)
   - Link becomes: `roadaid://reset-password?token=abc123`
   - Android opens your app
   - ✅ Works correctly

## Additional Configuration (Optional)

### If You Have a Web Version
If you plan to have a web-based password reset page:

**Site URL:**
```
https://yourdomain.com
```

**Redirect URLs:**
```
https://yourdomain.com/auth/callback
https://yourdomain.com/reset-password
roadaid://confirm-signup
roadaid://reset-password
roadaid://auth-callback
```

Your web server would detect mobile users and redirect them to the deep link.

### If Mobile-Only (Current Setup)
Keep it simple:

**Site URL:**
```
roadaid://
```

**Redirect URLs:** (as listed above)

## Testing Checklist

After changing Site URL to `roadaid://`:

- [ ] Send test signup confirmation email
- [ ] Click primary button → App should open ✅
- [ ] Click alternative link → App should open ✅
- [ ] Send test password reset email  
- [ ] Click primary button → App should open ✅
- [ ] Click alternative link → App should open ✅

## Files Updated in This Project

1. **EMAIL_TEMPLATE_CONFIRM_SIGNUP.html** ✅
   - Uses `roadaid://confirm-signup` deep link
   - Anti-spam optimized

2. **EMAIL_TEMPLATE_RESET_PASSWORD.html** ✅
   - Uses `roadaid://reset-password` deep link
   - Anti-spam optimized

3. **android/app/src/main/AndroidManifest.xml** ✅
   - Configured with `roadaid://` scheme
   - All intent filters set up

## Current Status

✅ Email templates are ready
✅ AndroidManifest.xml is configured
✅ Anti-spam warnings fixed
⏳ **TODO: Update Supabase Site URL to `roadaid://`**

## Quick Fix Summary

**Go to Supabase Dashboard right now:**
1. Authentication → URL Configuration
2. Change Site URL from `http://localhost:3000` to `roadaid://`
3. Save
4. Done! 🎉

The localhost error will be gone, and all email links will open your app correctly.
