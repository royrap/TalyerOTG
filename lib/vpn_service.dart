// Platform channel wrapper for VPN detection
// Exposes isVpnActive() which returns true when a VPN is detected on the device

import 'package:flutter/services.dart';

class VpnService {
  // Channel name (must match native handlers)
  static const MethodChannel _channel = MethodChannel('vpn_detection');

  // Calls native code (Android/iOS) that returns a boolean indicating VPN presence
  static Future<bool> isVpnActive() async {
    try {
      final bool result = await _channel.invokeMethod<bool>('isVpnActive') ?? false;
      return result;
    } catch (e) {
      // On error default to false (do not block) — you can change to true to be stricter
      return false;
    }
  }

  // Opens the device's VPN settings (or Settings app) so user can disable VPN manually.
  // Returns true when the intent/URL was successfully launched, false otherwise.
  static Future<bool> openVpnSettings() async {
    try {
      final bool result = await _channel.invokeMethod<bool>('openVpnSettings') ?? false;
      return result;
    } catch (e) {
      return false;
    }
  }
}
