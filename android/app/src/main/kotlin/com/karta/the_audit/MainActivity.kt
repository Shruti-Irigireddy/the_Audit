package com.karta.the_audit

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_audit/export_share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareExport") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val filePath = call.argument<String>("filePath")

                if (filePath.isNullOrBlank()) {
                    result.error("INVALID_FILE", "filePath is required", null)
                    return@setMethodCallHandler
                }

                val file = File(filePath)

                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "Export file was not found", null)
                    return@setMethodCallHandler
                }

                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file,
                )
                val mimeType = when (call.argument<String>("exportFormat")?.uppercase()) {
                    "PDF" -> "application/pdf"
                    "CSV" -> "text/csv"
                    else -> "application/octet-stream"
                }
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }

                startActivity(Intent.createChooser(intent, "Share export"))
                result.success(null)
            }
    }
}
