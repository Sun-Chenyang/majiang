package dev.kawuxing.kawuxing

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 仅用于视觉测试：adb shell am start ... --es prefill "0,1,2,…"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kawuxing/debug")
            .setMethodCallHandler { call, result ->
                if (call.method == "getPrefill") {
                    result.success(intent?.getStringExtra("prefill") ?: "")
                } else {
                    result.notImplemented()
                }
            }
    }
}
