package com.grammarlens.llama_inference

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin that exposes Android memory information via MethodChannel.
 *
 * Uses [ActivityManager] to provide accurate runtime memory data for
 * model loading decisions in the llama inference engine.
 */
class LlamaInferencePlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getMemoryInfo" -> result.success(getMemoryInfo())
            else -> result.notImplemented()
        }
    }

    /**
     * Collects memory information from [ActivityManager] and system properties.
     *
     * Returns a map with:
     * - `totalMemBytes`: Total physical RAM (from MemoryInfo.totalMem).
     * - `availMemBytes`: Currently available RAM (from MemoryInfo.availMem).
     * - `lowMemory`: Whether the system considers itself in a low-memory state.
     * - `threshold`: The memory threshold below which the system is "low memory" (bytes).
     * - `largeMemoryClass`: The max heap size (MB) available with `android:largeHeap`.
     * - `memoryClass`: The default max heap size (MB) for the app.
     * - `isLowRamDevice`: Whether ActivityManager considers this a low-RAM device.
     */
    private fun getMemoryInfo(): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)

        return mapOf(
            "totalMemBytes" to mi.totalMem,
            "availMemBytes" to mi.availMem,
            "lowMemory" to mi.lowMemory,
            "threshold" to mi.threshold,
            "largeMemoryClass" to am.largeMemoryClass,
            "memoryClass" to am.memoryClass,
            "isLowRamDevice" to am.isLowRamDevice,
        )
    }

    companion object {
        const val CHANNEL_NAME = "com.grammarlens/memory"
    }
}
