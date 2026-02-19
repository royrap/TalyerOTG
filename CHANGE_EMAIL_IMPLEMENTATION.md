# 📧 Change Email Implementation - Complete Guide

## 🎯 What's Implemented

Kumpleto na ang change email functionality para sa RoadAid app! Ito ang mga na-implement:

### ✅ **Files Created/Updated:**

1. **Deep Link Handler** - `lib/services/roadaid_deep_link_service.dart`
   - Added `email-change` case sa switch statement
   - Created `_handleEmailChange()` method
   - Handles both PKCE flow (code) at legacy flow (tokens)

2. **Change Email Screen** - `lib/screens/change_email_screen.dart`
   - Complete UI para sa email change
   - Form validation
   - Password confirmation
   - Success/error handling

3. **Backend Service** - `lib/services/profile_service.dart`
   - Already existing `updateUserEmail()` method
   - Email validation at duplicate checking
   - Auth user update integration

## 🔗 **Change Email URL Structure**

Ang change email confirmation link ay dapat sumusunod sa format:

```
roadaid://email-change?code=<recovery_code>
```

O para sa legacy format:
```
roadaid://email-change?access_token=<token>&refresh_token=<token>&type=email_change
```

## 🛠️ **How It Works**

### **Step 1: User Initiates Email Change**
```dart
// Navigate to change email screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const ChangeEmailScreen()),
);
```

### **Step 2: Supabase Sends Confirmation Email**
- User enters new email at password
- App calls `ProfileService.updateUserEmail()`
- Supabase sends confirmation email sa new email address

### **Step 3: User Clicks Confirmation Link**
- Link format: `roadaid://email-change?code=<code>`
- Deep link service catches the URL
- Calls `_handleEmailChange()` method

### **Step 4: Email Change Confirmed**
- Code is exchanged for session using `exchangeCodeForSession()`
- User session updated with new email
- Success message shown
- User redirected to dashboard

## 📱 **User Flow**

1. **Profile Screen** → "Change Email" button
2. **Change Email Screen** → Fill form (new email + password)
3. **Confirmation Email** → Sent to new email address
4. **Click Link** → `roadaid://email-change?code=...`
5. **Success** → Email updated, user redirected

## 🔧 **Integration with Profile Screens**

Para ma-access ang change email screen, add ang button sa mga profile screens:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangeEmailScreen()),
    );
  },
  child: const Text('Change Email'),
)
```

## ⚠️ **Supabase Configuration Required**

Make sure na configured sa Supabase dashboard:

### **1. Email Templates**
- Go to Authentication > Email Templates
- Configure "Change Email" template
- Set redirect URL to: `roadaid://email-change`

### **2. Site URL Settings**
- Go to Authentication > URL Configuration
- Add `roadaid://` sa allowed origins
- Set redirect URLs properly

### **3. SMTP Settings**
- Configure email provider para sa confirmation emails
- Test email sending functionality

## 🧪 **Testing Guide**

### **Test Email Change Flow:**
1. Login to the app
2. Go to profile/settings
3. Click "Change Email"
4. Enter new email + current password
5. Check new email for confirmation link
6. Click the link (should open app)
7. Verify email change success

### **Test Error Cases:**
- **Invalid current password** → Shows error message
- **Email already in use** → Shows error message
- **Expired confirmation link** → Shows expiration message
- **Invalid confirmation link** → Shows invalid link message

## 📋 **URL Patterns Supported**

Ang deep link service ay supports ang mga URL patterns:

```
roadaid://email-change?code=<recovery_code>
roadaid://email-change?access_token=<token>&refresh_token=<token>
roadaid://email-change?access_token=<token>&refresh_token=<token>&type=email_change
```

## 🔒 **Security Features**

- **Password Confirmation** - Requires current password
- **Email Validation** - Checks for valid email format
- **Duplicate Prevention** - Prevents using existing emails
- **Session Security** - Proper token handling
- **Expiration Handling** - Graceful handling of expired links

## 📊 **Error Handling**

Ang system ay nag-handle ng:
- ✅ Expired confirmation links
- ✅ Invalid confirmation codes
- ✅ Network errors
- ✅ Authentication errors
- ✅ Duplicate email addresses
- ✅ Invalid email formats

## 🚀 **Ready to Use**

Ang change email functionality ay ready na para gamitin! Just need to:

1. **Add navigation** sa change email screen from profile screens
2. **Configure Supabase** email templates and URLs
3. **Test** ang complete flow

## 📝 **Example Integration Code**

Para sa profile screen integration:

```dart
ListTile(
  leading: const Icon(Icons.email),
  title: const Text('Change Email'),
  subtitle: Text(user?.email ?? 'No email'),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangeEmailScreen()),
    );
  },
),
```

Tapos na ang implementation! The change email URL na hinahanap mo ay: **`roadaid://email-change`** 📧
