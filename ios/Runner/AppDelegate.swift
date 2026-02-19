import Flutter
import UIKit
import SystemConfiguration

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup MethodChannel for VPN detection
    if let controller = window?.rootViewController as? FlutterViewController {
      let vpnChannel = FlutterMethodChannel(name: "vpn_detection", binaryMessenger: controller.binaryMessenger)
      vpnChannel.setMethodCallHandler { call, result in
        if call.method == "isVpnActive" {
          result(self.isVpnConnected())
        } else if call.method == "openVpnSettings" {
          // iOS doesn't offer a direct VPN settings URL for third-party apps.
          // Open the app settings page; user can navigate to VPN from Settings.
          if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
              UIApplication.shared.open(url, options: [:]) { opened in
                result(opened)
              }
            } else {
              result(false)
            }
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Checks system proxy settings for scoped network interfaces (utun/tun/ppp/ipsec)
  private func isVpnConnected() -> Bool {
    guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
          let scoped = cfDict["__SCOPED__"] as? [String: Any] else {
      return false
    }

    for key in scoped.keys {
      let lower = key.lowercased()
      if lower.contains("tun") || lower.contains("utun") || lower.contains("ppp") || lower.contains("ipsec") || lower.contains("pptp") {
        return true
      }
    }

    return false
  }
}
