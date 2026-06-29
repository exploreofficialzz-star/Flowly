package com.chastechgroup.flowly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build

class MainActivity : FlutterActivity() {

    private val CHANNEL = "flowly/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPlayStoreInstall" -> {
                        try {
                            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                packageManager
                                    .getInstallSourceInfo(packageName)
                                    .installingPackageName
                            } else {
                                @Suppress("DEPRECATION")
                                packageManager.getInstallerPackageName(packageName)
                            }
                            result.success(installer == "com.android.vending")
                        } catch (e: Exception) {
                            // If we can't determine, assume Play Store (safe default)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
