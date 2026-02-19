# PayMongo Connection Issues - Troubleshooting Guide

## Issue: ERR_CONNECTION_REFUSED in WebView

### Symptoms
- WebView shows `net::ERR_CONNECTION_REFUSED` error
- PayMongo checkout URL fails to load: `https://checkout.paymongo.com/cs_...`
- Payment flow gets stuck at loading screen

### Root Causes

1. **Network Connectivity**
   - Device not connected to internet
   - Firewall blocking PayMongo domains
   - DNS resolution issues

2. **Test Mode vs Production**
   - Using test API keys (`pk_test_...`) but trying to access production URLs
   - Test checkout sessions may have limited availability

3. **WebView Configuration**
   - Missing internet permission in Android manifest
   - WebView not properly initialized
   - Security restrictions blocking external URLs

### Solutions

#### 1. Verify Internet Connection
```dart
// Add connectivity check before opening PayMongo
import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> checkConnectivity() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}
```

#### 2. Check Android Permissions
Ensure `AndroidManifest.xml` has internet permission:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### 3. WebView Configuration
Update WebView initialization in payment screen:
```dart
WebView(
  initialUrl: checkoutUrl,
  javascriptMode: JavascriptMode.unrestricted,
  onWebViewCreated: (WebViewController controller) {
    // Enable DOM storage and JavaScript
  },
  onPageStarted: (String url) {
    print('🌐 Loading: $url');
  },
  onPageFinished: (String url) {
    print('✅ Loaded: $url');
  },
  onWebResourceError: (WebResourceError error) {
    print('❌ WebView error: ${error.description}');
    if (error.errorCode == -2) {
      // ERR_NAME_NOT_RESOLVED or ERR_CONNECTION_REFUSED
      _showErrorDialog('Network Error', 
        'Cannot connect to payment gateway. Please check your internet connection.');
    }
  },
)
```

#### 4. Add Fallback Error Handling
```dart
void _handlePaymentError(String errorCode) {
  if (errorCode.contains('CONNECTION_REFUSED')) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text(
          'Cannot connect to PayMongo. Please check:\n'
          '1. Internet connection is active\n'
          '2. Not using VPN that blocks payment sites\n'
          '3. Try again in a few moments'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retryPayment();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
```

#### 5. Test with Production Keys
If using test mode, the checkout URLs may not be fully functional. Consider:
- Switching to PayMongo production API keys for real testing
- Using PayMongo's sandbox environment properly
- Verifying API key permissions in PayMongo dashboard

#### 6. Add Timeout Handling
```dart
Timer? _loadingTimeout;

@override
void initState() {
  super.initState();
  _loadingTimeout = Timer(const Duration(seconds: 30), () {
    if (mounted && !_pageLoaded) {
      _showTimeoutError();
    }
  });
}

void _showTimeoutError() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connection Timeout'),
      content: const Text('Payment gateway is taking too long to respond.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context); // Return to invoice
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              // Reload WebView
            });
          },
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
```

### Testing Checklist

- [ ] Device has active internet connection
- [ ] Can access `https://www.google.com` in device browser
- [ ] Can access `https://paymongo.com` in device browser
- [ ] Android manifest has `INTERNET` permission
- [ ] Using correct API keys (test vs production)
- [ ] PayMongo dashboard shows API is active
- [ ] No VPN or proxy interfering
- [ ] WebView JavaScript is enabled
- [ ] Checkout session created successfully (check response)
- [ ] Checkout URL is valid and accessible

### Alternative: Use GCash Direct (No WebView)
If WebView continues to fail, implement GCash direct payment:
```dart
// Create source instead of checkout session
final sourceResponse = await createGCashSource(amount, description);
final gcashUrl = sourceResponse['data']['attributes']['redirect']['checkout_url'];

// Open in external browser instead of WebView
import 'package:url_launcher/url_launcher.dart';
await launchUrl(Uri.parse(gcashUrl), mode: LaunchMode.externalApplication);
```

### Monitoring
Add logging to track WebView lifecycle:
```dart
print('🌐 Navigation to: $url');
print('❌ WebView error: ${error.errorCode} - ${error.description}');
print('✅ Payment completed detected, redirecting...');
```

## Current Log Analysis

From your logs:
```
I/flutter: 🌐 Navigation to: https://checkout.paymongo.com/cs_...
I/flutter: ❌ WebView error: net::ERR_CONNECTION_REFUSED
```

This indicates:
1. ✅ Checkout session created successfully
2. ✅ Redirect URL received
3. ❌ WebView cannot connect to PayMongo servers

**Most Likely Cause**: Device internet connectivity issue or PayMongo test environment limitation.

**Immediate Fix**: Test on different network (mobile data vs WiFi) or use actual payment in production mode.
