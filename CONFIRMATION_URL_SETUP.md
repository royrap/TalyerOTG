# 🔗 ROADAID CONFIRMATION URL SETUP GUIDE

## 🎯 Ano ang ConfirmationURL?

Ang `{{ .ConfirmationURL }}` sa email templates ay automatically generated ng Supabase. Ito ay nagiging:

```
https://your-project.supabase.co/auth/v1/verify?token=xxx&type=signup&redirect_to=YOUR_APP_URL
```

## 📱 Configuration para sa RoadAid App

### 1. Supabase Site URL Configuration

Sa Supabase Dashboard:
1. Go to **Settings** → **General** → **Configuration**
2. Set ang **Site URL** to:
   ```
   roadaid://auth-callback
   ```
   O kaya:
   ```
   https://yourdomain.com/auth-callback
   ```

### 2. Redirect URLs Configuration

Sa Supabase Dashboard:
1. Go to **Authentication** → **Settings** → **URL Configuration**
2. Add sa **Redirect URLs**:
   ```
   roadaid://auth-callback
   roadaid://confirm-signup
   roadaid://reset-password
   roadaid://magic-link
   https://yourdomain.com/auth-callback
   https://yourdomain.com/confirm-signup
   ```

### 3. Email Template Redirect Configuration

Para sa bawat authentication action, pwede mo i-specify ang redirect:

#### A. Signup Confirmation
```dart
// Sa signup code mo
await _supabase.auth.signUp(
  email: email,
  password: password,
  emailRedirectTo: 'roadaid://confirm-signup', // Redirect sa app
);
```

#### B. Password Reset
```dart
await _supabase.auth.resetPasswordForEmail(
  email,
  redirectTo: 'roadaid://reset-password',
);
```

#### C. Magic Link
```dart
await _supabase.auth.signInWithOtp(
  email: email,
  emailRedirectTo: 'roadaid://magic-link',
);
```

## 🔧 Deep Link Configuration sa Flutter

### 1. Android Configuration

Sa `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <!-- Standard launch intent -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Deep link intents for auth -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="roadaid" />
    </intent-filter>
    
    <!-- Specific auth callbacks -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="roadaid" android:host="confirm-signup" />
    </intent-filter>
    
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="roadaid" android:host="reset-password" />
    </intent-filter>
    
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="roadaid" android:host="magic-link" />
    </intent-filter>
</activity>
```

### 2. iOS Configuration

Sa `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>roadaid.auth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>roadaid</string>
        </array>
    </dict>
</array>

<!-- Specific auth callback schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>roadaid.confirm-signup</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>roadaid</string>
        </array>
        <key>CFBundleURLResourceSpecification</key>
        <dict>
            <key>CFBundleURLName</key>
            <string>confirm-signup</string>
        </dict>
    </dict>
</array>
```

## 🎯 Flutter Deep Link Handling

### 1. Install uni_links package

Sa `pubspec.yaml`:
```yaml
dependencies:
  uni_links: ^0.5.1
  # O kaya latest version
```

### 2. Create Auth Deep Link Handler

```dart
// lib/services/deep_link_service.dart
import 'dart:async';
import 'package:uni_links/uni_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription? _linkSubscription;

  void initialize() {
    // Handle initial link (app opened via link)
    _handleInitialLink();
    
    // Handle incoming links (app already running)
    _linkSubscription = linkStream.listen(
      _handleIncomingLink,
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleIncomingLink(initialLink);
      }
    } catch (e) {
      print('Error handling initial link: $e');
    }
  }

  void _handleIncomingLink(String link) {
    print('🔗 Received deep link: $link');
    
    final uri = Uri.parse(link);
    
    switch (uri.host) {
      case 'confirm-signup':
        _handleSignupConfirmation(uri);
        break;
      case 'reset-password':
        _handlePasswordReset(uri);
        break;
      case 'magic-link':
        _handleMagicLink(uri);
        break;
      case 'auth-callback':
        _handleAuthCallback(uri);
        break;
      default:
        print('Unknown deep link host: ${uri.host}');
    }
  }

  void _handleSignupConfirmation(Uri uri) {
    print('✅ Handling signup confirmation');
    // Extract token and verify
    final token = uri.queryParameters['token'];
    if (token != null) {
      // Navigate to welcome screen or dashboard
      // NavigationService.navigateToWelcome();
    }
  }

  void _handlePasswordReset(Uri uri) {
    print('🔑 Handling password reset');
    final token = uri.queryParameters['token'];
    if (token != null) {
      // Navigate to password reset screen
      // NavigationService.navigateToPasswordReset(token);
    }
  }

  void _handleMagicLink(Uri uri) {
    print('✨ Handling magic link');
    // Navigate to dashboard after magic link login
    // NavigationService.navigateToDashboard();
  }

  void _handleAuthCallback(Uri uri) {
    print('🔄 Handling auth callback');
    // General auth callback handling
    final token = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    
    if (token != null) {
      // Set session and navigate
      Supabase.instance.client.auth.setSession(token);
      // NavigationService.navigateToDashboard();
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

### 3. Initialize Deep Links sa Main App

```dart
// lib/main.dart
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(/* your config */);
  
  // Initialize deep links
  DeepLinkService().initialize();
  
  runApp(RoadAidApp());
}

class RoadAidApp extends StatefulWidget {
  @override
  _RoadAidAppState createState() => _RoadAidAppState();
}

class _RoadAidAppState extends State<RoadAidApp> {
  @override
  void dispose() {
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // your app config
    );
  }
}
```

## 🌐 Alternative: Web Redirect Page

Kung gusto mo ng web page na mag-redirect sa app:

### 1. Create Web Confirmation Page

```html
<!-- public/auth-callback.html -->
<!DOCTYPE html>
<html>
<head>
    <title>RoadAid - Authentication</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #b00c01 0%, #ff6b35 100%);
            color: white;
        }
        .container {
            max-width: 400px;
            margin: 0 auto;
            background: white;
            color: #333;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .btn {
            background: #b00c01;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 5px;
            display: inline-block;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚗 RoadAid</h1>
        <p>Authentication successful!</p>
        <p>Opening RoadAid app...</p>
        <a href="roadaid://auth-callback" class="btn">Open RoadAid App</a>
        <p><small>If the app doesn't open automatically, click the button above.</small></p>
    </div>

    <script>
        // Auto-redirect to app
        setTimeout(() => {
            window.location.href = 'roadaid://auth-callback';
        }, 2000);
        
        // Fallback: Try to open app store if app not installed
        setTimeout(() => {
            // Android
            if (/Android/i.test(navigator.userAgent)) {
                window.location.href = 'https://play.google.com/store/apps/details?id=com.roadaid.app';
            }
            // iOS
            else if (/iPhone|iPad|iPod/i.test(navigator.userAgent)) {
                window.location.href = 'https://apps.apple.com/app/roadaid/idXXXXXXXXX';
            }
        }, 5000);
    </script>
</body>
</html>
```

### 2. Host Web Page

Upload sa hosting service (Vercel, Netlify, Firebase Hosting) at i-set ang URL sa Supabase redirect URLs.

## 📋 Complete Configuration Checklist

- [ ] **Supabase Site URL** configured
- [ ] **Redirect URLs** added sa Supabase
- [ ] **Android deep links** configured sa manifest
- [ ] **iOS deep links** configured sa Info.plist
- [ ] **uni_links package** installed
- [ ] **DeepLinkService** implemented
- [ ] **Auth callbacks** handled properly
- [ ] **Web fallback page** created (optional)
- [ ] **App store fallbacks** configured
- [ ] **Testing** on real devices

## 🧪 Testing Deep Links

### Test Commands

```bash
# Android testing
adb shell am start -W -a android.intent.action.VIEW -d "roadaid://confirm-signup?token=test" com.roadaid.app

# iOS testing (simulator)
xcrun simctl openurl booted "roadaid://confirm-signup?token=test"
```

### Manual Testing

1. **Send test email** through Supabase
2. **Click confirmation link** sa mobile device
3. **Verify app opens** automatically
4. **Check proper navigation** sa tamang screen

Ganito ang flow:
1. User clicks **"Confirm Your Account"** sa email
2. Opens **browser** with Supabase confirmation URL
3. **Supabase verifies** token
4. **Redirects** to `roadaid://confirm-signup`
5. **RoadAid app opens** automatically
6. **Deep link handler** navigates to welcome screen

Perfect setup para sa seamless user experience! 🚀
