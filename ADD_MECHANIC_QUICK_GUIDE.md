# Add Mechanic Feature - Quick Reference Guide

## 🚀 Quick Start

### For Talyer Owners:

1. **Open the app** and navigate to the "Mechanics Performance" screen
2. **Click the orange "Add Mechanic" button** (floating action button at bottom-right)
3. **Fill in the mechanic details**:
   - Tap the circular placeholder to add a profile picture
   - Enter email, first name, last name, phone number
   - Specify specialization (e.g., "Engine Repair", "Electrical", "Brakes")
   - Enter years of experience
4. **Click "Add Mechanic"**
5. **Success!** The mechanic will receive a welcome email with their login credentials

---

## 📧 What Happens After Adding a Mechanic?

### Automatic Actions:
1. ✅ User account created in system
2. ✅ Profile picture uploaded to storage
3. ✅ Temporary password generated (12 characters, secure)
4. ✅ Email sent with credentials and instructions
5. ✅ Email verification token created
6. ✅ Mechanic added to shop roster
7. ✅ Activity logged for audit trail

### Email Contains:
- Welcome message from shop owner
- Login credentials (email + temporary password)
- Step-by-step instructions:
  1. Verify email
  2. Download RoadAid Mechanic App
  3. Login with temporary password
  4. Change password on first login
- Expiry notice (7 days)

---

## 🔐 For Mechanics - First Login Process

### Step 1: Check Your Email
- Look for email from RoadAid
- Subject: "Welcome to [Shop Name] - RoadAid Mechanic Account"
- **Save your temporary password** from the email

### Step 2: Verify Your Email
- Click the verification link in the email
- This activates your account

### Step 3: Download the App
- Download "RoadAid Mechanic" from app store
- Or use the link provided in the email

### Step 4: First Login
- Open the app
- Enter your email
- Enter the temporary password from email
- Click "Sign In"

### Step 5: Change Password (Required)
**You will automatically be taken to the password change screen**
- Enter your temporary password
- Create a new strong password:
  - Minimum 8 characters
  - At least 1 uppercase letter
  - At least 1 lowercase letter
  - At least 1 number
- Confirm your new password
- Click "Change Password & Continue"

### Step 6: Start Working!
- You're now logged into the Mechanic Dashboard
- You can now accept jobs, view assignments, and more

---

## ❗ Important Notes

### For Talyer Owners:
- ⚠️ **Profile picture is required** - cannot add mechanic without it
- ⚠️ **Email must be unique** - cannot use an email that's already registered
- ⚠️ Temporary password expires in 7 days
- ⚠️ Mechanic cannot login until they verify their email
- ✅ You can add multiple mechanics at any time
- ✅ All mechanics will appear in the "Mechanics Performance" list

### For Mechanics:
- ⚠️ **Must verify email first** - you cannot login without verifying
- ⚠️ **Must change password on first login** - you cannot skip this step
- ⚠️ Temporary password expires in 7 days - complete setup within this time
- ⚠️ If you lose your temporary password, contact your shop owner
- ✅ Your new password should be strong and memorable
- ✅ After password change, you can login normally anytime

---

## 🔧 Troubleshooting

### "Profile picture is required" error
- **Solution**: Tap the circular placeholder and select an image from your gallery or take a photo

### "A user with this email already exists" error
- **Solution**: Use a different email address. Each mechanic needs a unique email.

### Mechanic didn't receive email
- **Solution**: 
  1. Check spam/junk folder
  2. Verify email address is correct
  3. Wait a few minutes and check again
  4. Contact support if still not received

### "Please verify your email before logging in" message
- **Solution**: Check your email inbox for the verification link and click it first

### Forgot temporary password
- **Solution**: Contact your shop owner to resend credentials or generate a new invitation

### "Password must contain..." validation errors
- **Solution**: Ensure your new password has:
  - At least 8 characters
  - One uppercase letter (A-Z)
  - One lowercase letter (a-z)
  - One number (0-9)

### Cannot navigate back from password change screen
- **This is by design** - Password change is mandatory on first login for security
- Complete the password change to continue

---

## 🎯 Best Practices

### For Talyer Owners:
1. ✅ Use professional profile pictures
2. ✅ Verify mechanic details before submitting
3. ✅ Inform mechanic they will receive an email
4. ✅ Remind mechanics to check spam folder
5. ✅ Keep track of mechanics you've added
6. ✅ Use clear, descriptive specializations

### For Mechanics:
1. ✅ Check email immediately after being added
2. ✅ Verify email right away
3. ✅ Choose a strong, memorable password
4. ✅ Save your new password securely
5. ✅ Complete setup within 7 days
6. ✅ Test login after password change

---

## 📱 Screenshots Guide

### 1. Mechanics Performance Screen
- Orange "Add Mechanic" button at bottom-right corner
- List of existing mechanics above

### 2. Add Mechanic Dialog
- Circular profile picture picker at top
- Form fields for all details
- Blue info box explaining email process
- Orange "Add Mechanic" button at bottom

### 3. First Login Password Change Screen
- Orange info banner at top
- Current password field
- New password field
- Confirm password field
- Blue password requirements box
- "Change Password & Continue" button

---

## 🔒 Security Features

1. **Secure Password Generation**: 12-character random passwords with mixed case, numbers, and special characters
2. **Email Verification Required**: Cannot login without verifying email first
3. **Mandatory Password Change**: Must change password on first login
4. **Password Strength Requirements**: Enforced strong password policy
5. **Temporary Password Expiry**: 7-day expiration for security
6. **Audit Logging**: All actions are logged for security review
7. **One-Time Use**: Temporary passwords are marked as used after change

---

## 📊 Database Records Created

When you add a mechanic, the following records are created:

1. **User Profile** - Basic information and settings
2. **Service Provider** - Mechanic's service capabilities
3. **Shop Mechanic** - Association with your shop
4. **Temporary Password** - For initial login
5. **Email Verification Token** - For email confirmation
6. **Email Notification** - Welcome email with credentials
7. **Admin Activity Log** - Record of who added the mechanic

---

## ⏱️ Timeline

| Action | When | Duration |
|--------|------|----------|
| Add mechanic | Immediate | ~5 seconds |
| Email sent | Within 1 minute | - |
| Email verification | Manual (mechanic) | - |
| First login | After verification | - |
| Password change | Required immediately | ~2 minutes |
| Ready to work | After password change | - |
| Temp password expires | If not used | 7 days |

---

## 📞 Support

If you encounter any issues:

1. **Check this guide first** - Most common issues are covered above
2. **Check database logs** - Look at admin_activity_logs and account_security_logs
3. **Verify email settings** - Ensure email service is configured correctly
4. **Check Supabase Storage** - Verify profile-images bucket exists
5. **Contact technical support** - Provide error messages and screenshots

---

## ✅ Success Indicators

### Mechanic Added Successfully:
- ✅ Green success message appears
- ✅ Mechanic list refreshes and shows new mechanic
- ✅ Email sent confirmation

### Mechanic Setup Complete:
- ✅ Email verified
- ✅ Password changed successfully
- ✅ Can login to dashboard
- ✅ Profile shows in shop mechanics list

---

## 🎉 Congratulations!

You've successfully added a new mechanic to your shop! They can now:
- Accept job assignments
- View customer details
- Navigate to customer locations
- Complete service requests
- Scan QR codes for payment release
- Track their earnings and job history

Your mechanic is now part of the RoadAid team! 🚗🔧
