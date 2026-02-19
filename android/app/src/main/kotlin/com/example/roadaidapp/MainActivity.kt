package com.example.roadaidapp

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
	private val CHANNEL = "vpn_detection"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"isVpnActive" -> {
					try {
						result.success(isVpnActive())
					} catch (e: Exception) {
						result.error("ERROR", e.message, null)
					}
				}
				"openVpnSettings" -> {
					try {
						val intent = android.content.Intent(android.provider.Settings.ACTION_VPN_SETTINGS)
						intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("ERROR", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	// Detect VPN using NetworkCapabilities when possible, fallback to interface scan
	private fun isVpnActive(): Boolean {
		val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

		// Modern check (API 23+)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			try {
				val network = cm.activeNetwork ?: null
				val caps = cm.getNetworkCapabilities(network)
				if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
					return true
				}
			} catch (ignored: Exception) {
			}
		} else {
			try {
				@Suppress("DEPRECATION")
				val ni = cm.getNetworkInfo(ConnectivityManager.TYPE_VPN)
				if (ni != null && ni.isConnectedOrConnecting) return true
			} catch (ignored: Exception) {
			}
		}

		// Fallback: scan network interfaces for common VPN interface names
		try {
			val ifaces = NetworkInterface.getNetworkInterfaces()
			while (ifaces.hasMoreElements()) {
				val nif = ifaces.nextElement()
				val name = nif.name?.lowercase() ?: continue
				if ((name.contains("tun") || name.contains("tap") || name.contains("ppp") ||
							name.contains("pptp") || name.contains("ipsec") || name.contains("pppd")) && nif.isUp) {
					return true
				}
			}
		} catch (ignored: Exception) {
		}

		return false
	}
}
