package ly.count.dart.countly_flutter_lite

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CountlyFlutterLitePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_GET -> result.success(readLegacyData())
            METHOD_CLEAR_ANDROID -> {
                clearAndroidData()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun readLegacyData(): Map<String, Any?> {
        val prefs: SharedPreferences = context.getSharedPreferences(ANDROID_PREFERENCES, Context.MODE_PRIVATE)
        fun anyToString(key: String): String? {
            val v = prefs.all[key]
            return when (v) {
                null -> null
                is String -> v
                else -> v.toString()
            }
        }
        val androidData = mapOf(
            "deviceId" to anyToString(KEY_DEVICE_ID),
            "deviceIdType" to anyToString(KEY_DEVICE_ID_TYPE),
            "requestQueue" to anyToString(KEY_REQUEST_QUEUE),
            "eventQueue" to anyToString(KEY_EVENT_QUEUE),
            "remoteConfig" to anyToString(KEY_REMOTE_CONFIG),
            "serverConfig" to anyToString(KEY_SERVER_CONFIG),
            "schemaVersion" to anyToString(KEY_SCHEMA_VERSION),
        )
        val hasData = androidData.values.any { value ->
            when (value) {
                is String -> value.isNotEmpty()
                else -> value != null
            }
        }
        return if (hasData) mapOf("android" to androidData) else emptyMap()
    }

    private fun clearAndroidData() {
        val prefs: SharedPreferences = context.getSharedPreferences(ANDROID_PREFERENCES, Context.MODE_PRIVATE)
        prefs.edit()
            .remove(KEY_DEVICE_ID)
            .remove(KEY_DEVICE_ID_TYPE)
            .remove(KEY_REQUEST_QUEUE)
            .remove(KEY_EVENT_QUEUE)
            .remove(KEY_REMOTE_CONFIG)
            .remove(KEY_SERVER_CONFIG)
            .remove(KEY_SCHEMA_VERSION)
            .apply()
    }

    companion object {
        private const val CHANNEL_NAME = "countly_flutter_lite/migration"
        private const val METHOD_GET = "getLegacyData"
        private const val METHOD_CLEAR_ANDROID = "clearAndroidLegacyData"
        private const val ANDROID_PREFERENCES = "COUNTLY_STORE"
        private const val KEY_REQUEST_QUEUE = "CONNECTIONS"
        private const val KEY_EVENT_QUEUE = "EVENTS"
        private const val KEY_DEVICE_ID = "ly.count.android.api.DeviceId.id"
        private const val KEY_DEVICE_ID_TYPE = "ly.count.android.api.DeviceId.type"
        private const val KEY_REMOTE_CONFIG = "REMOTE_CONFIG"
        private const val KEY_SERVER_CONFIG = "SERVER_CONFIG"
        private const val KEY_SCHEMA_VERSION = "SCHEMA_VERSION"
    }
}
