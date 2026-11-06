package com.khulani.smart_campus_safety

import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCsv: String? = null

    private val createCsvDocument =
        registerForActivityResult(
            ActivityResultContracts.CreateDocument("text/csv")
        ) { uri: Uri? ->
            val result = pendingResult
            val contents = pendingCsv
            pendingResult = null
            pendingCsv = null

            if (result != null) {
                if (uri == null) {
                    result.success(false)
                } else {
                    try {
                        val output = contentResolver.openOutputStream(uri)
                            ?: throw IllegalStateException(
                                "The selected location could not be opened."
                            )

                        output.use {
                            it.write((contents ?: "").toByteArray(Charsets.UTF_8))
                        }

                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "CSV_WRITE_FAILED",
                            error.message,
                            null
                        )
                    }
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.khulani.smart_campus_safety/incident_export"
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveCsv") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (pendingResult != null) {
                result.error(
                    "EXPORT_IN_PROGRESS",
                    "A CSV export is already in progress.",
                    null
                )
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
                ?.takeIf { it.isNotBlank() }
                ?: "smart_campus_incidents.csv"

            val contents = call.argument<String>("contents")
            if (contents == null) {
                result.error(
                    "INVALID_CSV",
                    "CSV contents were not provided.",
                    null
                )
                return@setMethodCallHandler
            }

            pendingResult = result
            pendingCsv = contents

            try {
                createCsvDocument.launch(fileName)
            } catch (error: Exception) {
                pendingResult = null
                pendingCsv = null
                result.error(
                    "SAVE_PICKER_FAILED",
                    error.message,
                    null
                )
            }
        }
    }
}
