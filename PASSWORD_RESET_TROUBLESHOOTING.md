# Password Reset Troubleshooting Guide

## Error: "Invalid password reset link - no authentication tokens found"

### Common Causes:
1. Missing Redirect URLs in Supabase
2. Email template not properly configured  
3. URL format issues
4. Token parsing issues

### Step-by-Step Fix:

## Step 1: Check Supabase Redirect URLs
Go to Supabase Dashboard → Authentication → Settings → Redirect URLs
Add: roadaid://reset-password

## Step 2: Update Email Template
Go to Supabase Dashboard → Authentication → Settings → Email Templates → Reset Password
Make sure {{ .ConfirmationURL }} is properly formatted.

## Step 3: Test the Flow
1. Clear app data (logout if logged in)
2. Go to Forgot Password screen
3. Enter your email and click "Send Reset Email"
4. Check your email for the reset link
5. Click the link - it should open the app
6. Check console logs for debugging info

## Debug Console Output
Look for these logs:
- Handling password reset
- Full URI received
- Token parameters
- Session recovery status

The updated code now provides detailed debugging information to help identify the issue.
