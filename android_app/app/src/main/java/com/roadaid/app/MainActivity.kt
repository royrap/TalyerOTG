package com.roadaid.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import java.net.NetworkInterface
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check VPN before any other initialization
        if (VpnUtils.isVpnActive(this)) {
            VpnUtils.showVpnDialog(this)
            return
        }

        // Continue with normal app initialization
        setContentView(R.layout.activity_main)
        // ... other startup logic
    }

    private fun isVpnActive(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        // Modern check (API 23+): preferred method
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val network = cm.activeNetwork
                val caps = cm.getNetworkCapabilities(network)
                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) return true
            } catch (_: Exception) {
                // ignore and fall through to other checks
            }
        } else {
            // Legacy check for older Android versions
            @Suppress("DEPRECATION")
            try {
                val ni = cm.getNetworkInfo(ConnectivityManager.TYPE_VPN)
                if (ni != null && ni.isConnectedOrConnecting) return true
            } catch (_: Exception) {
                // ignore
            }
        }

        // Fallback: scan network interfaces for common VPN interface names (tun/tap/ppp/etc.)
        try {
            val ifaces = NetworkInterface.getNetworkInterfaces()
            while (ifaces.hasMoreElements()) {
                val nif = ifaces.nextElement()
                val name = nif.name?.lowercase() ?: continue
                if ((name.contains("tun") || name.contains("tap") || name.contains("ppp") ||
                            name.contains("pptp") || name.contains("ipsec") || name.contains("pppd")) && nif.isUp
                ) {
                    return true
                }
            }
        } catch (_: Exception) {
            // ignore
        }

        return false
    }

    private fun showVpnDialog() {
        // Use non-cancelable dialog to force user acknowledgement
        AlertDialog.Builder(this)
            .setTitle("VPN detected")
            .setMessage("VPN detected. Please turn off your VPN to use this app.")
            .setCancelable(false)
            .setPositiveButton("OK") { _, _ ->
                // Close the app after user acknowledges
                finishAffinity()
                // ensure process termination as fallback
                System.exit(0)
            }
            .show()
    }
}
