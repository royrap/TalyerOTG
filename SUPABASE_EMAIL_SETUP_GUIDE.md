# 📧 ROADAID SUPABASE EMAIL TEMPLATES - IMPLEMENTATION GUIDE

## 🎯 Overview
This guide will help you set up professional, branded email templates for all RoadAid authentication flows in your Supabase dashboard.

## 📋 Templates Included
1. **Confirm Signup** - Welcome new users and confirm their account
2. **Invite User** - Invite mechanics and service providers to join
3. **Magic Link** - Password-free secure login
4. **Change Email Address** - Confirm email address changes
5. **Reset Password** - Secure password reset process
6. **Reauthentication** - Additional security verification

## 🚀 Step-by-Step Implementation

### Step 1: Access Supabase Email Templates
1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** → **Settings** → **Email Templates**
3. You'll see 6 different template types

### Step 2: Configure Each Template

#### 📝 Template 1: CONFIRM SIGNUP
1. Click on **"Confirm signup"** template
2. Copy the HTML code from `supabase_email_templates.html` (Confirm Signup section)
3. Paste it into the **Subject** and **Body** fields:
   - **Subject**: `Welcome to RoadAid - Confirm Your Account`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

#### 📝 Template 2: INVITE USER
1. Click on **"Invite user"** template
2. Copy the HTML code from the Invite User section
3. Set the template:
   - **Subject**: `You're Invited to Join RoadAid`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

#### 📝 Template 3: MAGIC LINK
1. Click on **"Magic Link"** template
2. Copy the HTML code from the Magic Link section
3. Set the template:
   - **Subject**: `Your RoadAid Magic Login Link`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

#### 📝 Template 4: CHANGE EMAIL ADDRESS
1. Click on **"Change Email Address"** template
2. Copy the HTML code from the Change Email section
3. Set the template:
   - **Subject**: `Confirm Your New Email Address - RoadAid`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

#### 📝 Template 5: RESET PASSWORD
1. Click on **"Reset Password"** template
2. Copy the HTML code from the Reset Password section
3. Set the template:
   - **Subject**: `Reset Your RoadAid Password`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

#### 📝 Template 6: REAUTHENTICATION
1. Click on **"Reauthentication"** template
2. Copy the HTML code from the Reauthentication section
3. Set the template:
   - **Subject**: `RoadAid Security Verification Required`
   - **Body**: [Copy the full HTML template]
4. Click **Save**

## 🔧 Template Variables Explained

Supabase automatically replaces these variables in your templates:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ .ConfirmationURL }}` | Action link (confirm, reset, login) | https://yourapp.com/confirm?token=... |
| `{{ .Email }}` | User's email address | user@example.com |
| `{{ .DateTime }}` | Current timestamp | 2025-08-21 19:00:00 |

## 🎨 Customization Options

### Colors & Branding
- **Primary Color**: `#b00c01` (RoadAid Red)
- **Secondary Color**: `#ff6b35` (Orange gradient)
- **Background**: `#f4f4f4` (Light gray)

### Font & Typography
- **Font Family**: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif
- **Headers**: 28px, bold
- **Body**: 16px, normal
- **Buttons**: 16px, bold

### Responsive Design
- **Max Width**: 600px for optimal mobile viewing
- **Mobile-friendly**: Responsive design for all devices
- **Email Client Compatible**: Works with Gmail, Outlook, Apple Mail, etc.

## 🧪 Testing Your Templates

### 1. Preview Templates
- Use Supabase's built-in preview feature
- Check how templates look in different email clients

### 2. Test Authentication Flows
```bash
# Test signup confirmation
curl -X POST 'https://your-project.supabase.co/auth/v1/signup' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"email": "test@example.com", "password": "testpass123"}'

# Test password reset
curl -X POST 'https://your-project.supabase.co/auth/v1/recover' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"email": "test@example.com"}'
```

### 3. Check Email Delivery
- Test with different email providers (Gmail, Outlook, Yahoo)
- Verify links work correctly
- Check spam folder delivery

## 🔗 Integration with RoadAid Features

### Mechanic Invitation Flow
When adding mechanics to shops, use the invite template:
```dart
// In your TalyerOwnerService
await _supabase.auth.admin.inviteUserByEmail(
  mechanicEmail,
  data: {
    'role': 'mechanic',
    'shop_id': shopId,
    'invited_by': talyerOwnerId,
  },
);
```

### Magic Link for Mechanics
Provide password-free login for mechanics:
```dart
await _supabase.auth.signInWithOtp(
  email: mechanicEmail,
  emailRedirectTo: 'roadaid://mechanic-dashboard',
);
```

### Password Reset Integration
```dart
await _supabase.auth.resetPasswordForEmail(
  userEmail,
  redirectTo: 'roadaid://reset-password',
);
```

## 📱 Mobile App Deep Links

Configure these redirect URLs for mobile app integration:

### Android Deep Links
```xml
<!-- In android/app/src/main/AndroidManifest.xml -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="roadaid" />
</intent-filter>
```

### iOS Deep Links
```xml
<!-- In ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>roadaid.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>roadaid</string>
        </array>
    </dict>
</array>
```

## 🛡️ Security Best Practices

### Email Security
- All templates include security warnings
- Clear expiration times for links
- Instructions for users to contact support if suspicious

### Link Validation
- Verify all `{{ .ConfirmationURL }}` links work
- Test link expiration behavior
- Ensure proper HTTPS redirects

### User Education
Templates include:
- Security tips for password creation
- Warnings about phishing attempts
- Clear contact information for support

## 📞 Support Information

Update these placeholders in your templates:
- **Support Email**: `support@roadaid.com`
- **Security Email**: `security@roadaid.com`
- **Phone Support**: `1-800-ROADAID`
- **Emergency**: `1-800-ROADAID-SEC`

## 🎉 Verification Checklist

- [ ] All 6 templates configured in Supabase
- [ ] Subject lines set for each template
- [ ] HTML body pasted correctly
- [ ] Variables (`{{ .ConfirmationURL }}`, etc.) preserved
- [ ] Mobile responsiveness tested
- [ ] Email delivery tested
- [ ] Deep links configured for mobile app
- [ ] Security warnings included
- [ ] Support contact information updated
- [ ] Brand colors and fonts applied

## 🚀 Go Live

Once all templates are configured and tested:

1. **Enable email templates** in Supabase
2. **Update your app** to use the new authentication flows
3. **Monitor email delivery** and user feedback
4. **Update support documentation** with new email examples

Your RoadAid authentication emails are now professional, secure, and fully integrated with your system! 🎊
