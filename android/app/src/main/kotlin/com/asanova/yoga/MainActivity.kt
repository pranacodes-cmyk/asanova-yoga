package com.asanova.yoga

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** "asanova/market": device id (Android ID), SIM/network country and installed UPI apps. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "asanova/market").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> {
                    val tm = getSystemService(TELEPHONY_SERVICE) as? TelephonyManager
                    result.success(mapOf(
                        "deviceId" to (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""),
                        "simCountry" to (tm?.simCountryIso ?: ""),
                        "networkCountry" to (tm?.networkCountryIso ?: ""),
                    ))
                }
                "upiApps" -> {
                    val probe = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
                    @Suppress("DEPRECATION")
                    val apps = packageManager.queryIntentActivities(probe, 0).map {
                        mapOf(
                            "package" to it.activityInfo.packageName,
                            "name" to it.loadLabel(packageManager).toString(),
                            "icon" to iconPng(it.loadIcon(packageManager)),
                        )
                    }.distinctBy { it["package"] }
                    result.success(apps)
                }
                "openUpi" -> {
                    val url = call.argument<String>("url") ?: ""
                    val pkg = call.argument<String>("package")
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        if (!pkg.isNullOrEmpty()) intent.setPackage(pkg)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** The app's real launcher icon as a 96px PNG, so the paywall shows Google Pay/PhonePe logos. */
    private fun iconPng(d: Drawable): ByteArray? = try {
        val bmp = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        d.setBounds(0, 0, 96, 96)
        d.draw(c)
        java.io.ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    } catch (_: Exception) { null }
}
