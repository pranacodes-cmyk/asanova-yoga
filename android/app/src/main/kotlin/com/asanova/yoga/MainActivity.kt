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
                    // Some apps require BROWSABLE or a populated pay URI; merge all valid handlers.
                    // Discovery only: never launch these probes or create a payment here.
                    val uris = listOf("upi://pay", "upi://pay?pa=discovery%40upi&pn=Asanova&am=1.00&cu=INR")
                    val probes = uris.flatMap { uri ->
                        listOf(Intent(Intent.ACTION_VIEW, Uri.parse(uri)),
                            Intent(Intent.ACTION_VIEW, Uri.parse(uri)).addCategory(Intent.CATEGORY_BROWSABLE))
                    }
                    val priority = listOf("com.phonepe.app", "com.google.android.apps.nbu.paisa.user",
                        "net.one97.paytm", "in.org.npci.upiapp", "in.amazon.mShop.android.shopping",
                        "com.dreamplug.androidapp", "com.mobikwik_new")
                    @Suppress("DEPRECATION")
                    val handlers = probes.flatMap { packageManager.queryIntentActivities(it, 0) } +
                        priority.flatMap { pkg -> probes.flatMap {
                            packageManager.queryIntentActivities(Intent(it).setPackage(pkg), 0)
                        } }
                    val apps = handlers.distinctBy { it.activityInfo.packageName }.map {
                        mapOf(
                            "package" to it.activityInfo.packageName,
                            "name" to packageManager.getApplicationLabel(it.activityInfo.applicationInfo).toString(),
                            "icon" to iconPng(packageManager.getApplicationIcon(it.activityInfo.applicationInfo)),
                        )
                    }
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
