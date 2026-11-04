package com.zongzi.schedule.widget

import android.content.Context
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition

/**
 * [v3.1.0] 课表小组件交互切日动作回调（前一天 / 后一天 / 快速回到今天）
 * 采用 Glance 官方 updateAppWidgetState 驱动活跃 Session 毫秒级重组
 */
class SwitchDayActionCallback : ActionCallback {
    companion object {
        val deltaKey = ActionParameters.Key<Int>("delta")
        const val PREFS_NAME = "cw_widget_prefs"
        const val KEY_DAY_OFFSET = "widget_day_offset"
        val GLANCE_KEY_DAY_OFFSET = intPreferencesKey(KEY_DAY_OFFSET)
        val GLANCE_KEY_REFRESH_TICK = longPreferencesKey("widget_refresh_tick")
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val delta = parameters[deltaKey] ?: 0
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val fallbackOffset = sp.getInt(KEY_DAY_OFFSET, 0)

        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            val currentOffset = prefs[GLANCE_KEY_DAY_OFFSET] ?: fallbackOffset
            // delta == 0 时重置回今天，否则在 -7 ~ +14 天内微调
            val newOffset = if (delta == 0) 0 else (currentOffset + delta).coerceIn(-7, 14)
            sp.edit().putInt(KEY_DAY_OFFSET, newOffset).apply()

            prefs.toMutablePreferences().apply {
                this[GLANCE_KEY_DAY_OFFSET] = newOffset
                this[GLANCE_KEY_REFRESH_TICK] = System.currentTimeMillis()
            }
        }

        ScheduleGlanceWidget().update(context, glanceId)
        WidgetAlarmScheduler.scheduleNextTick(context)
    }
}
