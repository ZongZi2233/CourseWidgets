package com.zongzi.schedule.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.updateAll
import com.zongzi.schedule.LiveUpdateNotificationManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray

/**
 * [v3.0.0] 课表桌面小组件广播接收器与精准分钟级生命周期调度
 */
class ScheduleWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ScheduleGlanceWidget()

    companion object {
        const val ACTION_SCHEDULE_WIDGET_UPDATE = "com.zongzi.schedule.widget.ACTION_UPDATE"
        const val ACTION_WIDGET_TICK = "com.zongzi.schedule.widget.ACTION_MINUTE_TICK"

        fun updateAll(context: Context) {
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    ScheduleGlanceWidget().updateAll(context)
                } catch (_: Exception) {}
            }
            WidgetAlarmScheduler.scheduleNextTick(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action == ACTION_SCHEDULE_WIDGET_UPDATE ||
            action == ACTION_WIDGET_TICK ||
            action == Intent.ACTION_TIME_TICK ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_SCREEN_ON ||
            action == Intent.ACTION_USER_PRESENT
        ) {
            updateAll(context)
        }
    }
}

/**
 * 现代小组件分钟级精准更新调度器
 * 智能探测当前是否有课程进行或即将开始（45分钟内），
 * 仅在活跃周期执行分钟级精确唤醒，非活跃周期安睡，杜绝不必要的耗电。
 */
object WidgetAlarmScheduler {
    fun scheduleNextTick(context: Context) {
        val prefs = context.getSharedPreferences(LiveUpdateNotificationManager.PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(LiveUpdateNotificationManager.KEY_UPCOMING_COURSES, null) ?: return
        val courses = try {
            JSONArray(jsonStr)
        } catch (_: Exception) {
            return
        }
        if (courses.length() == 0) return

        val now = System.currentTimeMillis()
        var hasActiveOrNearCourse = false
        var nextWakeup = Long.MAX_VALUE

        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val st = c.optLong("startTime", 0L)
            val et = c.optLong("endTime", 0L)
            if (st <= now && et > now) {
                // 正在上课中，需分钟级刷新进度与倒计时
                hasActiveOrNearCourse = true
                break
            } else if (st > now) {
                val diffMin = (st - now) / 60000
                if (diffMin <= 45) {
                    // 临近开课（45分钟内），开启分钟级倒计时刷新
                    hasActiveOrNearCourse = true
                    break
                }
                val startWindow = st - 45 * 60 * 1000
                if (startWindow > now && startWindow < nextWakeup) {
                    nextWakeup = startWindow
                }
            }
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ScheduleWidgetReceiver::class.java).apply {
            action = ScheduleWidgetReceiver.ACTION_WIDGET_TICK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            2002,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (hasActiveOrNearCourse) {
                // 精准对齐下一分钟起点 (+500ms 缓冲)
                val nextMinute = ((now / 60000) + 1) * 60000 + 500
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                }
            } else if (nextWakeup != Long.MAX_VALUE && nextWakeup > now) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextWakeup, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextWakeup, pendingIntent)
                }
            }
        } catch (_: Exception) {}
    }
}

