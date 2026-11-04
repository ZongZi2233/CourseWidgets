package com.zongzi.schedule.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import com.zongzi.schedule.LiveUpdateNotificationManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray

/**
 * [v3.1.0] 课表桌面小组件广播接收器与精准分钟级生命周期调度
 * 修复：
 * 1. 引入 goAsync() 保活广播协程，防止系统在挂起函数完成前冻结进程；
 * 2. 每次刷新时递增 GLANCE_KEY_REFRESH_TICK，强制已处于活跃 Session 的小组件触发重组读取最新课程数据。
 */
class ScheduleWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ScheduleGlanceWidget()

    companion object {
        const val ACTION_SCHEDULE_WIDGET_UPDATE = "com.zongzi.schedule.widget.ACTION_UPDATE"
        const val ACTION_WIDGET_TICK = "com.zongzi.schedule.widget.ACTION_MINUTE_TICK"

        suspend fun refreshAllNow(context: Context) {
            try {
                val manager = GlanceAppWidgetManager(context)
                val glanceIds = manager.getGlanceIds(ScheduleGlanceWidget::class.java)
                val sp = context.getSharedPreferences(SwitchDayActionCallback.PREFS_NAME, Context.MODE_PRIVATE)
                val savedOffset = sp.getInt(SwitchDayActionCallback.KEY_DAY_OFFSET, 0)
                val tick = System.currentTimeMillis()

                for (id in glanceIds) {
                    updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                        prefs.toMutablePreferences().apply {
                            if (this[SwitchDayActionCallback.GLANCE_KEY_DAY_OFFSET] == null) {
                                this[SwitchDayActionCallback.GLANCE_KEY_DAY_OFFSET] = savedOffset
                            }
                            this[SwitchDayActionCallback.GLANCE_KEY_REFRESH_TICK] = tick
                        }
                    }
                    ScheduleGlanceWidget().update(context, id)
                }
            } catch (_: Exception) {}
            WidgetAlarmScheduler.scheduleNextTick(context)
        }

        fun updateAll(context: Context) {
            CoroutineScope(Dispatchers.Main).launch {
                refreshAllNow(context)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action == ACTION_SCHEDULE_WIDGET_UPDATE ||
            action == ACTION_WIDGET_TICK ||
            action == Intent.ACTION_TIME_TICK ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_SCREEN_ON ||
            action == Intent.ACTION_USER_PRESENT
        ) {
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    refreshAllNow(context)
                } finally {
                    try {
                        pendingResult.finish()
                    } catch (_: Exception) {}
                }
            }
        }
    }
}

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

        val midnightCal = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_YEAR, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 5)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val nextMidnight = midnightCal.timeInMillis
        if (nextMidnight > now) {
            nextWakeup = nextMidnight
        }

        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val st = c.optLong("startTime", 0L)
            val et = c.optLong("endTime", 0L)
            if (st <= now && et > now) {
                hasActiveOrNearCourse = true
                break
            } else if (st > now) {
                val diffMin = (st - now) / 60000
                if (diffMin <= 45) {
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
