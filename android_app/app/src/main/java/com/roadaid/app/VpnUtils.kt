package com.roadaid.app

import android.content.Context
import android.net.ConnectivityManager
package com.roadaid.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import androidx.appcompat.app.AlertDialog
import android.app.Activity
import java.net.NetworkInterface
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import android.widget.Toast
import android.app.Activity
import android.content.Context
import java.net.NetworkInterface

object VpnUtils {

    /**
     * Returns true if a VPN connection appears to be active.
     * Uses NetworkCapabilities for API 23+ and falls back to legacy methods
     * and a network-interface scan for broader coverage.
     */
    fun isVpnActive(context: Context): Boolean {
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

    fun showVpnDialog(context: Context) {
        // Ensure dialog is shown on UI thread
        if (context is Activity) {
            context.runOnUiThread {
                AlertDialog.Builder(context)
                    .setTitle("VPN detected")
                    .setMessage("VPN detected. Please turn off your VPN to use this app.")
                    .setCancelable(false)
                    .setPositiveButton("OK") { _, _ ->
                        // Finish activity stack cleanly
                        context.finishAffinity()
                    }
                    .show()
            }
        }
    }
}
