package com.zongzi.schedule

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val THEME_CHANNEL = "com.zongzi.schedule/theme"
    private val IMAGE_PICKER_CHANNEL = "com.zongzi.schedule/image_picker"
    private val LIVE_UPDATE_CHANNEL = "com.zongzi.schedule/live_update"
    
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 1001

    override fun getFlutterShellArgs(): io.flutter.embedding.engine.FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        args.add("--enable-impeller=true")
        args.add("--impeller-backend=vulkan")
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Android 16 Promoted Ongoing Live Updates 通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "postPromotedLiveUpdate" -> {
                    val id = call.argument<Int>("id") ?: 1000
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val subLocation = call.argument<String>("subLocation")
                    val progress = call.argument<Int>("progress") ?: 0
                    val maxProgress = call.argument<Int>("maxProgress") ?: 100
                    val showProgress = call.argument<Boolean>("showProgress") ?: false
                    val isCountingDown = call.argument<Boolean>("isCountingDown") ?: false
                    val whenTime = call.argument<Long>("whenTime")
                    val usesChronometer = call.argument<Boolean>("usesChronometer") ?: false

                    try {
                        postPromotedLiveUpdate(
                            id = id,
                            title = title,
                            body = body,
                            subLocation = subLocation,
                            progress = progress,
                            maxProgress = maxProgress,
                            showProgress = showProgress,
                            isCountingDown = isCountingDown,
                            whenTime = whenTime,
                            usesChronometer = usesChronometer
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LIVE_UPDATE_ERROR", e.message, null)
                    }
                }
                "cancelLiveUpdate" -> {
                    val id = call.argument<Int>("id") ?: 1000
                    try {
                        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        notificationManager.cancel(id)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "canPostPromotedNotifications" -> {
                    val canPost = checkCanPostPromotedNotifications()
                    result.success(canPost)
                }
                else -> result.notImplemented()
            }
        }
        
        // 主题色通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THEME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemAccentColor" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val color = getSystemAccentColor()
                        result.success(color)
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 图片选择器通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        // Android 14+ 使用 Photo Picker（不需要权限）
                        pickImageWithPhotoPicker(result)
                    } else {
                        result.error("UNSUPPORTED", "需要 Android 14+", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            android.webkit.CookieManager.getInstance().flush()
        } catch (e: Exception) {}
    }

    override fun onStop() {
        super.onStop()
        try {
            android.webkit.CookieManager.getInstance().flush()
        } catch (e: Exception) {}
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun getSystemAccentColor(): Int {
        return resources.getColor(android.R.color.system_accent1_500, theme)
    }
    
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun pickImageWithPhotoPicker(result: MethodChannel.Result) {
        pendingResult = result
        
        // 使用 Android 14+ Photo Picker API
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES).apply {
            type = "image/*"
        }
        
        startActivityForResult(intent, PICK_IMAGE_REQUEST)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PICK_IMAGE_REQUEST) {
            if (resultCode == RESULT_OK) {
                data?.data?.let { uri ->
                    handleImageUri(uri)
                } ?: pendingResult?.error("NO_IMAGE", "未选择图片", null)
            } else {
                pendingResult?.error("CANCELLED", "用户取消选择", null)
            }
            pendingResult = null
        }
    }
    
    private fun handleImageUri(uri: Uri) {
        try {
            // 将图片复制到应用私有目录
            val inputStream = contentResolver.openInputStream(uri)
            if (inputStream == null) {
                pendingResult?.error("READ_ERROR", "无法读取图片", null)
                return
            }
            
            // 创建保存目录
            val appDir = File(filesDir, "backgrounds")
            if (!appDir.exists()) {
                appDir.mkdirs()
            }
            
            // 生成文件名
            val fileName = "bg_${System.currentTimeMillis()}.png"
            val outputFile = File(appDir, fileName)
            
            // 复制文件
            FileOutputStream(outputFile).use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()
            
            // 返回文件路径
            pendingResult?.success(outputFile.absolutePath)
        } catch (e: Exception) {
            pendingResult?.error("SAVE_ERROR", "保存图片失败: ${e.message}", null)
        }
    }

    private fun postPromotedLiveUpdate(
        id: Int,
        title: String,
        body: String,
        subLocation: String?,
        progress: Int,
        maxProgress: Int,
        showProgress: Boolean,
        isCountingDown: Boolean,
        whenTime: Long?,
        usesChronometer: Boolean
    ) {
        val channelId = "live_course_updates_v3"
        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                "课程实时提醒",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Android 16 Live Updates 课程倒计时"
                setShowBadge(true)
                enableLights(true)
                lightColor = 0xFFFF9A9E.toInt()
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            android.app.Notification.Builder(this)
        }

        builder.setContentTitle(title)
        builder.setContentText(body)
        builder.setSmallIcon(R.mipmap.ic_launcher)
        builder.setOngoing(true)
        builder.setOnlyAlertOnce(true)
        builder.setAutoCancel(false)
        builder.setCategory(android.app.Notification.CATEGORY_PROGRESS)
        builder.setColor(0xFFFF9A9E.toInt())

        if (subLocation != null && subLocation.isNotEmpty()) {
            builder.setSubText(subLocation)
            builder.setTicker(subLocation)
        }

        if (showProgress) {
            builder.setProgress(maxProgress, progress, false)
        }

        if (whenTime != null && whenTime > 0) {
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
            if (usesChronometer) {
                builder.setUsesChronometer(true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    builder.setChronometerCountDown(isCountingDown)
                }
            }
        }

        // Android 16 Live Update (Promoted Ongoing) 专属标志与 Extra 注入
        val extras = android.os.Bundle()
        extras.putBoolean("android.requestPromotedOngoing", true)
        builder.addExtras(extras)

        // API 36+ 规范方法反射调用
        try {
            val method = builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
            method.invoke(builder, true)
        } catch (ignored: Throwable) {}

        // 点击意图返回应用
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            val pendingIntent = android.app.PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            builder.setContentIntent(pendingIntent)
        }

        val notification = builder.build()
        notification.flags = notification.flags or android.app.Notification.FLAG_ONGOING_EVENT

        try {
            val field = android.app.Notification::class.java.getField("FLAG_PROMOTED_ONGOING")
            notification.flags = notification.flags or field.getInt(null)
        } catch (ignored: Throwable) {}

        notificationManager.notify(id, notification)
    }

    private fun checkCanPostPromotedNotifications(): Boolean {
        return try {
            val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val method = notificationManager.javaClass.getMethod("canPostPromotedNotifications")
            method.invoke(notificationManager) as Boolean
        } catch (e: Throwable) {
            true // 默认开启或旧系统兼容
        }
    }
}
