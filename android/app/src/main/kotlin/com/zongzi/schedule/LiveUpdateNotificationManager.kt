package com.zongzi.schedule

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.text.Html
import android.util.Log

object LiveUpdateNotificationManager {
    const val CHANNEL_ID = "live_course_updates_v3"
    const val NOTIFICATION_ID = 1000
    const val PREFS_NAME = "cw_live_update_prefs"
    const val KEY_UPCOMING_COURSES = "upcoming_courses_json"

    fun postNotification(
        context: Context,
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
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程实时提醒",
                NotificationManager.IMPORTANCE_HIGH
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
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        val titleSpan = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Html.fromHtml(title, Html.FROM_HTML_MODE_LEGACY)
        } else {
            @Suppress("DEPRECATION")
            Html.fromHtml(title)
        }
        val bodySpan = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Html.fromHtml(body.replace("\n", "<br/>"), Html.FROM_HTML_MODE_LEGACY)
        } else {
            @Suppress("DEPRECATION")
            Html.fromHtml(body.replace("\n", "<br/>"))
        }

        builder.setContentTitle(titleSpan)
        builder.setContentText(bodySpan)
        builder.setStyle(Notification.BigTextStyle().bigText(bodySpan))
        builder.setSmallIcon(R.mipmap.ic_launcher)
        try {
            val appIconBitmap = BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
            if (appIconBitmap != null) {
                builder.setLargeIcon(appIconBitmap)
            }
        } catch (_: Exception) {}
        builder.setOngoing(true)
        builder.setOnlyAlertOnce(true)
        builder.setAutoCancel(false)
        builder.setCategory(Notification.CATEGORY_PROGRESS)

        // [v2.10.1] 状态栏药丸/胶囊内容：无论是否使用秒表，均注入 subText/ticker，并反射支持 Android 16 setShortCriticalText
        // 彻底杜绝各大系统（HyperOS / OriginOS / ColorOS）药丸胶囊直接空白无内容的问题！
        if (subLocation != null && subLocation.isNotEmpty()) {
            builder.setSubText(subLocation)
            builder.setTicker(subLocation)
            try {
                val method = builder.javaClass.getMethod("setShortCriticalText", CharSequence::class.java)
                method.invoke(builder, subLocation)
            } catch (ignored: Throwable) {}
        }

        if (showProgress) {
            builder.setProgress(maxProgress, progress, false)
        } else {
            builder.setProgress(0, 0, false)
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

        try {
            val method = builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
            method.invoke(builder, true)
        } catch (ignored: Throwable) {}

        // 点击意图返回应用
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setContentIntent(pendingIntent)
        }

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT

        try {
            val field = Notification::class.java.getField("FLAG_PROMOTED_ONGOING")
            notification.flags = notification.flags or field.getInt(null)
        } catch (ignored: Throwable) {}

        notificationManager.notify(id, notification)
    }

    /// [v2.10.1] 基于系统 AlarmManager 注册硬件级精确唤醒闹钟
    fun scheduleNextAlarm(context: Context, triggerAtMs: Long) {
        if (triggerAtMs <= System.currentTimeMillis()) return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, CourseAlarmReceiver::class.java).apply {
            action = CourseAlarmReceiver.getAction(context)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            2001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent
                )
            }
            Log.d("CourseWidgets", "⏰ 已成功设置 AlarmManager 课表精准唤醒闹钟: $triggerAtMs")
        } catch (e: Exception) {
            Log.e("CourseWidgets", "设置精准闹钟失败: ${e.message}")
        }
    }

    /// 取消课表精准唤醒闹钟
    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, CourseAlarmReceiver::class.java).apply {
            action = CourseAlarmReceiver.getAction(context)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            2001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.cancel(pendingIntent)
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_UPCOMING_COURSES)
                .apply()
            Log.d("CourseWidgets", "🛑 已取消 AlarmManager 课表精准唤醒闹钟")
        } catch (e: Exception) {
            Log.e("CourseWidgets", "取消精准闹钟失败: ${e.message}")
        }
    }
}

