package com.healthsyncteam.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "openBackgroundSettings" -> result.success(openBackgroundSettings())
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "openBatteryOptimizationSettings" ->
                        result.success(openBatteryOptimizationSettings())
                    "openAppSettings" -> result.success(openAppSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens the screen where this phone lets an app keep running in the
     * background. Xiaomi, Oppo and Vivo hide it in their own security apps,
     * and their battery savers can stop scheduled dose reminders from firing.
     * Falls back to this app's system settings page, which exists everywhere.
     */
    private fun openBackgroundSettings(): Boolean {
        val vendorScreens = listOf(
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            ),
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
            ),
            ComponentName(
                "com.oplus.safecenter",
                "com.oplus.safecenter.permission.startup.StartupAppListActivity"
            ),
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            ),
            ComponentName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
            )
        )
        for (component in vendorScreens) {
            val intent = Intent().setComponent(component)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                try {
                    startActivity(intent)
                    return true
                } catch (_: Exception) {
                    // Listed but not exported on this build; try the next one.
                }
            }
        }
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Whether Android's battery optimisation is off for this app. When it is
     * on, Doze can delay or drop scheduled reminders. Before Android 6 there
     * was no such setting, so the answer is yes.
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Opens the system list where the user can turn battery optimisation off.
     * The direct "allow this app" prompt needs the
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission, which Google Play
     * restricts, so the user picks HealthSync from the list instead.
     */
    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return openAppSettings()
        return try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (_: Exception) {
            openAppSettings()
        }
    }

    /** This app's system settings page: notifications, alarms, battery. */
    private fun openAppSettings(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (_: Exception) {
        false
    }

    companion object {
        private const val CHANNEL = "healthsync/device"
    }
}
