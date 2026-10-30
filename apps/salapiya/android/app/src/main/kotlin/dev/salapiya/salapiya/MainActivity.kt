package dev.salapiya.salapiya

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Hands a temporary copy to another app for reading only. The grant
        // covers this one file, and only for the app that opens it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salapiya/open_file")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val file = File(call.argument<String>("path")!!)
                val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
                val view = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, call.argument<String>("mime"))
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                try {
                    startActivity(view)
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }
}
