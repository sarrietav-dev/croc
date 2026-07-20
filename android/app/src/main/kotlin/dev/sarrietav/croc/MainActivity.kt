package dev.sarrietav.croc

import android.os.Handler
import android.os.Looper
import dev.sarrietav.crocbridge.Crocbridge
import dev.sarrietav.crocbridge.Listener
import dev.sarrietav.crocbridge.Transfer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val transferExecutor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var activeTransfer: Transfer? = null

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
            else -> result.notImplemented()
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
    }
}
