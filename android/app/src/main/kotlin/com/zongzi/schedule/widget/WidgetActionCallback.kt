package com.zongzi.schedule.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback

/**
 * [v3.0.0] 课表小组件交互切日动作回调（前一天 / 后一天 / 快速回到今天）
 */
class SwitchDayActionCallback : ActionCallback {
    companion object {
        val deltaKey = ActionParameters.Key<Int>("delta")
        const val PREFS_NAME = "cw_widget_prefs"
        const val KEY_DAY_OFFSET = "widget_day_offset"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val delta = parameters[deltaKey] ?: 0
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentOffset = prefs.getInt(KEY_DAY_OFFSET, 0)
        // delta == 0 时重置回今天，否则在 -7 ~ +14 天内循环微调
        val newOffset = if (delta == 0) 0 else (currentOffset + delta).coerceIn(-7, 14)
        prefs.edit().putInt(KEY_DAY_OFFSET, newOffset).apply()

        ScheduleGlanceWidget().update(context, glanceId)
    }
}
