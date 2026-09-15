package com.zongzi.schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("CourseWidgets", "🚀 收到系统广播: $action，准备恢复课表闹钟与通知")
        if (Intent.ACTION_BOOT_COMPLETED == action ||
            Intent.ACTION_MY_PACKAGE_REPLACED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action) {
            val alarmIntent = Intent(context, CourseAlarmReceiver::class.java).apply {
                this.action = CourseAlarmReceiver.ACTION_COURSE_WAKEUP
            }
            context.sendBroadcast(alarmIntent)
        }
    }
}
