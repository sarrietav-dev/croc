package dev.sarrietav.croc

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import dev.sarrietav.crocbridge.Crocbridge
import dev.sarrietav.crocbridge.Listener
import dev.sarrietav.crocbridge.Transfer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val transferExecutor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var activeTransfer: Transfer? = null
    private var pendingSave: PendingSave? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "generateCode" -> result.success(Crocbridge.generateCode())
            "startSend" -> startTransfer(call, result, true)
            "startReceive" -> startTransfer(call, result, false)
            "cancel" -> {
                activeTransfer?.cancel()
                result.success(null)
            }
            "saveFile" -> saveFile(call, result)
            "shareFile" -> shareFile(call, result)
            "pickFiles" -> pickFiles(result)
            else -> result.notImplemented()
        }
    }

    private fun pickFiles(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("picker_busy", "The file picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(intent, PICK_REQUEST_CODE)
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("save_busy", "Another save dialog is already open", null)
            return
        }
        val path = call.argument<String>("path").orEmpty()
        val name = call.argument<String>("name").orEmpty()
        if (!File(path).isFile) {
            result.error("missing_file", "The received file is no longer available", null)
            return
        }

        pendingSave = PendingSave(path, result)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startActivityForResult(intent, SAVE_REQUEST_CODE)
    }

    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path").orEmpty()
        val name = call.argument<String>("name").orEmpty()
        val file = File(path)
        if (!file.isFile) {
            result.error("missing_file", "The received file is no longer available", null)
            return
        }

        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, name)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Share $name"))
            result.success(null)
        } catch (error: Exception) {
            result.error("share_failed", error.message ?: "Unable to share file", null)
        }
    }

    @Deprecated("Deprecated in Android, retained for the asynchronous Flutter channel result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_REQUEST_CODE) {
            finishPicking(resultCode, data)
            return
        }
        if (requestCode != SAVE_REQUEST_CODE) return

        val pending = pendingSave ?: return
        pendingSave = null
        val destination = data?.data
        if (resultCode != Activity.RESULT_OK || destination == null) {
            pending.result.success(false)
            return
        }

        transferExecutor.execute {
            try {
                FileInputStream(pending.path).use { input ->
                    contentResolver.openOutputStream(destination, "w").use { output ->
                        requireNotNull(output) { "Unable to open the selected destination" }
                        input.copyTo(output)
                    }
                }
                mainHandler.post { pending.result.success(true) }
            } catch (error: Exception) {
                mainHandler.post {
                    pending.result.error("save_failed", error.message ?: "Unable to save file", null)
                }
            }
        }
    }

    private fun finishPicking(resultCode: Int, data: Intent?) {
        val result = pendingPick ?: return
        pendingPick = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) uris.add(clip.getItemAt(index).uri)
        } ?: data.data?.let(uris::add)

        transferExecutor.execute {
            try {
                val directory = File(cacheDir, "croc-picked").apply { mkdirs() }
                val files = uris.mapIndexed { index, uri ->
                    val displayName = queryDisplayName(uri) ?: "file-${System.currentTimeMillis()}-$index"
                    val safeName = displayName.replace(Regex("[\\/\\u0000]"), "_")
                    val destination = File(directory, "${System.nanoTime()}-$safeName")
                    contentResolver.openInputStream(uri).use { input ->
                        requireNotNull(input) { "Unable to read $displayName" }
                        destination.outputStream().use(input::copyTo)
                    }
                    mapOf("name" to displayName, "path" to destination.path, "size" to destination.length())
                }
                mainHandler.post { result.success(files) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("pick_failed", error.message ?: "Unable to open selected files", null)
                }
            }
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) null else cursor.getString(0)
        }
    }

    private fun startTransfer(call: MethodCall, result: MethodChannel.Result, isSender: Boolean) {
        if (activeTransfer != null) {
            result.error("busy", "A transfer is already active", null)
            return
        }

        val code = call.argument<String>("code").orEmpty()
        val relayAddress = call.argument<String>("relayAddress").orEmpty()
        val relayPorts = call.argument<String>("relayPorts").orEmpty()
        val relayPassword = call.argument<String>("relayPassword").orEmpty()
        val payload = if (isSender) {
            call.argument<String>("paths").orEmpty()
        } else {
            call.argument<String>("stagingDirectory").orEmpty()
        }

        val listener = object : Listener {
            override fun onEvent(event: String) {
                mainHandler.post { eventSink?.success(event) }
            }
        }
        val transfer = Crocbridge.newTransfer(listener, relayAddress, relayPorts, relayPassword)
        activeTransfer = transfer

        transferExecutor.execute {
            try {
                if (isSender) {
                    transfer.send(code, payload)
                } else {
                    transfer.receive(code, payload)
                }
                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("transfer_failed", error.message ?: "Transfer failed", null)
                }
            } finally {
                mainHandler.post { activeTransfer = null }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDestroy() {
        activeTransfer?.cancel()
        transferExecutor.shutdownNow()
        super.onDestroy()
    }

    private companion object {
        const val CONTROL_CHANNEL = "dev.sarrietav.croc/control"
        const val EVENT_CHANNEL = "dev.sarrietav.croc/events"
        const val SAVE_REQUEST_CODE = 7301
        const val PICK_REQUEST_CODE = 7302
    }

    private data class PendingSave(val path: String, val result: MethodChannel.Result)
}
