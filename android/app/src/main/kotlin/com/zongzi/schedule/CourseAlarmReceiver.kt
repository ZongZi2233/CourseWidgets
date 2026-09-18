package com.zongzi.schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CourseAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_COURSE_WAKEUP = "com.zongzi.schedule.ACTION_COURSE_WAKEUP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("CourseWidgets", "🔔 CourseAlarmReceiver 收到课表定时唤醒广播: ${intent.action}")

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "CourseWidgets:AlarmWakeLock"
        )
        wakeLock?.acquire(3000L) // 保持3秒CPU唤醒执行更新

        try {
            refreshNotificationFromSavedCourses(context)
            com.zongzi.schedule.widget.ScheduleWidgetReceiver.updateAll(context)
        } catch (e: Exception) {
            Log.e("CourseWidgets", "刷新课表通知失败: ${e.message}", e)
        } finally {
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            } catch (_: Exception) {}
        }
    }

    private fun refreshNotificationFromSavedCourses(context: Context) {
        val prefs = context.getSharedPreferences(LiveUpdateNotificationManager.PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(LiveUpdateNotificationManager.KEY_UPCOMING_COURSES, null) ?: return
        val courses = JSONArray(jsonStr)
        if (courses.length() == 0) return

        val now = System.currentTimeMillis()
        var currentCourse: org.json.JSONObject? = null
        var nextCourse: org.json.JSONObject? = null
        var nextWakeupTime: Long = Long.MAX_VALUE

        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val st = c.optLong("startTime", 0L)
            val et = c.optLong("endTime", 0L)

            // 正在上课中
            if (st <= now && et > now) {
                currentCourse = c
                if (et in (now + 1) until nextWakeupTime) {
                    nextWakeupTime = et
                }
            } else if (st > now) {
                if (nextCourse == null || st < nextCourse.optLong("startTime", Long.MAX_VALUE)) {
                    nextCourse = c
                }
                val tenMinBefore = st - 10 * 60 * 1000
                if (tenMinBefore > now && tenMinBefore < nextWakeupTime) {
                    nextWakeupTime = tenMinBefore
                }
                if (st in (now + 1) until nextWakeupTime) {
                    nextWakeupTime = st
                }
            }
        }

        val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())

        if (currentCourse != null) {
            val name = currentCourse.optString("name", "课程")
            val loc = currentCourse.optString("location", "")
            val st = currentCourse.optLong("startTime", now)
            val et = currentCourse.optLong("endTime", now)
            val totalMs = et - st
            val elapsedMs = now - st
            val remainingSec = Math.max(0, ((et - now) / 1000).toInt())
            val remainingMin = Math.ceil(remainingSec / 60.0).toInt()
            val progress = if (totalMs > 0) ((elapsedMs.toDouble() / totalMs) * 100).toInt().coerceIn(0, 100) else 0

            val locStr = if (loc.isNotEmpty() && !loc.contains("未知")) " ($loc)" else ""
            val title = "<b><font color=\"#FF5252\">正在上课</font></b> · <b>$name</b>"
            val subText = if (remainingMin > 0) "剩${remainingMin}分钟" else "即将下课"
            val body = "<b>$name</b>$locStr\n时间: ${timeFmt.format(Date(st))} ──●── ${timeFmt.format(Date(et))} (${totalMs / 60000}分钟 · 进度 $progress%)"

            LiveUpdateNotificationManager.postNotification(
                context = context,
                id = LiveUpdateNotificationManager.NOTIFICATION_ID,
                title = title,
                body = body,
                subLocation = subText,
                progress = progress,
                maxProgress = 100,
                showProgress = true,
                isCountingDown = true,
                whenTime = et,
                usesChronometer = true
            )
        } else if (nextCourse != null) {
            val name = nextCourse.optString("name", "课程")
            val loc = nextCourse.optString("location", "")
            val st = nextCourse.optLong("startTime", now)
            val et = nextCourse.optLong("endTime", now)
            val diffSec = Math.max(0, ((st - now) / 1000).toInt())
            val diffMin = diffSec / 60

            val locStr = if (loc.isNotEmpty() && !loc.contains("未知")) " ($loc)" else ""
            val startStr = timeFmt.format(Date(st))

            if (diffMin <= 45) {
                val subText = if (diffMin > 0) "${diffMin}分钟后上课" else "马上开始"
                val progress = (((45 - diffMin).toDouble() / 45) * 100).toInt().coerceIn(0, 100)
                val statusTag = if (diffMin <= 10) "马上开始" else "即将上课"
                val title = "<b><font color=\"#FFA000\">$statusTag</font></b> · <b>$name</b>"
                val body = "<b>$name</b>$locStr · $startStr 开课\n时间: 倒计时中 ──── $startStr · 请提前入座准备"

                LiveUpdateNotificationManager.postNotification(
                    context = context,
                    id = LiveUpdateNotificationManager.NOTIFICATION_ID,
                    title = title,
                    body = body,
                    subLocation = subText,
                    progress = progress,
                    maxProgress = 100,
                    showProgress = true,
                    isCountingDown = true,
                    whenTime = st,
                    usesChronometer = true
                )
            } else {
                val title = "<b>下节课 ($startStr)</b> · <b>$name</b>"
                val body = "<b>$name</b>$locStr\n时间: $startStr - ${timeFmt.format(Date(et))}"
                val subText = if (locStr.isNotEmpty()) loc.trim() else startStr

                LiveUpdateNotificationManager.postNotification(
                    context = context,
                    id = LiveUpdateNotificationManager.NOTIFICATION_ID,
                    title = title,
                    body = body,
                    subLocation = subText,
                    progress = 0,
                    maxProgress = 100,
                    showProgress = false,
                    isCountingDown = false,
                    whenTime = null,
                    usesChronometer = false
                )
            }
        }

        if (nextWakeupTime != Long.MAX_VALUE && nextWakeupTime > now) {
            LiveUpdateNotificationManager.scheduleNextAlarm(context, nextWakeupTime)
        }
    }
}
