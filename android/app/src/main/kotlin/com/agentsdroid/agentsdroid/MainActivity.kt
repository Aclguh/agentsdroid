package com.agentsdroid.agentsdroid

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.agentsdroid/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startOrUpdate" -> {
                    val title = call.argument<String>("title") ?: "AgentsDroid: 正在执行任务"
                    val body = call.argument<String>("body") ?: "后台执行保护中"
                    val urgent = call.argument<Boolean>("urgent") ?: false

                    val intent = Intent(this, AgentsDroidService::class.java).apply {
                        action = AgentsDroidService.ACTION_START_OR_UPDATE
                        putExtra(AgentsDroidService.EXTRA_TITLE, title)
                        putExtra(AgentsDroidService.EXTRA_BODY, body)
                        putExtra(AgentsDroidService.EXTRA_URGENT, urgent)
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    try {
                        val intent = Intent(this, AgentsDroidService::class.java).apply {
                            action = AgentsDroidService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(AgentsDroidService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }
}
