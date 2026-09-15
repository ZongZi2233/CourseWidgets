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

                    val upcomingCoursesJson = call.argument<String>("upcomingCoursesJson")
                    if (upcomingCoursesJson != null && upcomingCoursesJson.isNotEmpty()) {
                        getSharedPreferences(LiveUpdateNotificationManager.PREFS_NAME, android.content.Context.MODE_PRIVATE)
                            .edit()
                            .putString(LiveUpdateNotificationManager.KEY_UPCOMING_COURSES, upcomingCoursesJson)
                            .apply()
                    }
                    val nextWakeupMs = call.argument<Long>("nextWakeupMs")
                    if (nextWakeupMs != null && nextWakeupMs > System.currentTimeMillis()) {
                        LiveUpdateNotificationManager.scheduleNextAlarm(this, nextWakeupMs)
                    }

                    try {
                        LiveUpdateNotificationManager.postNotification(
                            context = this,
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
                "scheduleNextAlarm" -> {
                    val triggerAtMs = call.argument<Long>("triggerAtMs") ?: 0L
                    if (triggerAtMs > System.currentTimeMillis()) {
                        LiveUpdateNotificationManager.scheduleNextAlarm(this, triggerAtMs)
                    }
                    result.success(true)
                }
                "cancelLiveUpdate" -> {
                    val id = call.argument<Int>("id") ?: 1000
                    try {
                        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        notificationManager.cancel(id)
                        LiveUpdateNotificationManager.cancelAlarm(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "openIcsInCalendar" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = openIcsInCalendar(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_PATH", "filePath is null", null)
                    }
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
        LiveUpdateNotificationManager.postNotification(
            context = this,
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

    private fun openIcsInCalendar(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "text/calendar")
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val chooser = Intent.createChooser(intent, "导入课程表到系统日程")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            true
        } catch (e: Exception) {
            android.util.Log.e("CourseWidgets", "打开系统日历失败: ${e.message}", e)
            false
        }
    }
}
