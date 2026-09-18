package com.zongzi.schedule.widget

import android.content.Context
import android.content.Intent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.zongzi.schedule.LiveUpdateNotificationManager
import com.zongzi.schedule.MainActivity
import com.zongzi.schedule.R
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * [v3.0.0] CourseWidgets 2×2 旗舰液态超椭圆课程小组件 (基于 Jetpack Glance)
 */
class ScheduleGlanceWidget : GlanceAppWidget() {

    data class WidgetCourseData(
        val name: String,
        val location: String,
        val teacher: String,
        val startTime: Long,
        val endTime: Long,
        val statusText: String,
        val statusColor: Color,
        val progressPercent: Int,
        val isOngoing: Boolean
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences(SwitchDayActionCallback.PREFS_NAME, Context.MODE_PRIVATE)
        val dayOffset = prefs.getInt(SwitchDayActionCallback.KEY_DAY_OFFSET, 0)

        // 计算目标日期
        val targetCal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, dayOffset)
        }
        val targetDate = targetCal.time

        val monthDayFmt = SimpleDateFormat("M月d日", Locale.CHINA)
        val weekFmt = SimpleDateFormat("E", Locale.CHINA)
        val dateDisplay = if (dayOffset == 0) {
            "${monthDayFmt.format(targetDate)} ${weekFmt.format(targetDate)}"
        } else if (dayOffset == 1) {
            "明天 · ${weekFmt.format(targetDate)}"
        } else if (dayOffset == -1) {
            "昨天 · ${weekFmt.format(targetDate)}"
        } else {
            "${monthDayFmt.format(targetDate)} ${weekFmt.format(targetDate)}"
        }

        val courseData = loadTargetCourseData(context, targetCal, dayOffset)

        provideContent {
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(ImageProvider(R.drawable.bg_glass_widget))
                    .padding(8.dp)
            ) {
                Column(
                    modifier = GlanceModifier.fillMaxSize()
                ) {
                    // 顶部导航栏：日期指示徽章 + 交互切日控制胶囊
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(bottom = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = dateDisplay,
                            style = TextStyle(
                                color = ColorProvider(Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                        )
                        Spacer(modifier = GlanceModifier.defaultWeight())

                        // 切日前一天
                        Text(
                            text = "‹",
                            style = TextStyle(
                                color = ColorProvider(Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            ),
                            modifier = GlanceModifier
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to -1)
                                    )
                                )
                        )
                        Spacer(modifier = GlanceModifier.width(4.dp))

                        // 回到今天
                        Text(
                            text = "今",
                            style = TextStyle(
                                color = ColorProvider(if (dayOffset == 0) Color(0xFFFF9A9E) else Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 10.sp
                            ),
                            modifier = GlanceModifier
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to 0)
                                    )
                                )
                        )
                        Spacer(modifier = GlanceModifier.width(4.dp))

                        // 切日后一天
                        Text(
                            text = "›",
                            style = TextStyle(
                                color = ColorProvider(Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            ),
                            modifier = GlanceModifier
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to 1)
                                    )
                                )
                        )
                    }

                    // 核心课程卡片内容区：点击唤醒主应用本体
                    Box(
                        modifier = GlanceModifier
                            .fillMaxSize()
                            .background(ImageProvider(R.drawable.bg_glass_card))
                            .padding(8.dp)
                            .clickable(actionStartActivity(Intent(context, MainActivity::class.java)))
                    ) {
                        if (courseData != null) {
                            val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())
                            val timeStr = "${timeFmt.format(Date(courseData.startTime))} - ${timeFmt.format(Date(courseData.endTime))}"

                            Column(
                                modifier = GlanceModifier.fillMaxSize()
                            ) {
                                // 状态胶囊 + 课程时间
                                Row(
                                    modifier = GlanceModifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = courseData.statusText,
                                        style = TextStyle(
                                            color = ColorProvider(courseData.statusColor),
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 10.sp
                                        ),
                                        modifier = GlanceModifier
                                            .background(ImageProvider(R.drawable.bg_glass_badge))
                                            .padding(horizontal = 5.dp, vertical = 2.dp)
                                    )
                                    Spacer(modifier = GlanceModifier.defaultWeight())
                                    Text(
                                        text = timeStr,
                                        style = TextStyle(
                                            color = ColorProvider(Color(0xD0FFFFFF)),
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Medium
                                        )
                                    )
                                }

                                Spacer(modifier = GlanceModifier.height(4.dp))

                                // 课程名称
                                Text(
                                    text = courseData.name,
                                    maxLines = 2,
                                    style = TextStyle(
                                        color = ColorProvider(Color.White),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                )

                                Spacer(modifier = GlanceModifier.defaultWeight())

                                // 教室与教师
                                val roomText = if (courseData.location.isNotEmpty() && !courseData.location.contains("未知")) {
                                    courseData.location
                                } else {
                                    "未指定教室"
                                }
                                val subDetails = if (courseData.teacher.isNotEmpty()) {
                                    "$roomText · ${courseData.teacher}"
                                } else {
                                    roomText
                                }
                                Text(
                                    text = subDetails,
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color(0xB3FFFFFF)),
                                        fontSize = 11.sp
                                    )
                                )

                                // 正在上课时的进度条
                                if (courseData.isOngoing) {
                                    Spacer(modifier = GlanceModifier.height(3.dp))
                                    LinearProgressIndicator(
                                        progress = (courseData.progressPercent / 100f).coerceIn(0f, 1f),
                                        modifier = GlanceModifier.fillMaxWidth().height(3.dp),
                                        color = ColorProvider(courseData.statusColor),
                                        backgroundColor = ColorProvider(Color(0x33FFFFFF))
                                    )
                                }
                            }
                        } else {
                            // 空白休息状态
                            Column(
                                modifier = GlanceModifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Spacer(modifier = GlanceModifier.defaultWeight())
                                Text(
                                    text = if (dayOffset == 0) "今日课程已结束" else "当天暂无安排课程",
                                    style = TextStyle(
                                        color = ColorProvider(Color.White),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.sp
                                    )
                                )
                                Spacer(modifier = GlanceModifier.height(3.dp))
                                Text(
                                    text = "享受自由时光，好好休息吧~",
                                    style = TextStyle(
                                        color = ColorProvider(Color(0x99FFFFFF)),
                                        fontSize = 10.sp
                                    )
                                )
                                Spacer(modifier = GlanceModifier.defaultWeight())
                            }
                        }
                    }
                }
            }
        }
    }

    private fun loadTargetCourseData(
        context: Context,
        targetCal: Calendar,
        dayOffset: Int
    ): WidgetCourseData? {
        val prefs = context.getSharedPreferences(LiveUpdateNotificationManager.PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(LiveUpdateNotificationManager.KEY_UPCOMING_COURSES, null) ?: return null
        val courses = JSONArray(jsonStr)
        if (courses.length() == 0) return null

        val now = System.currentTimeMillis()
        val targetDayYear = targetCal.get(Calendar.YEAR)
        val targetDayOfYear = targetCal.get(Calendar.DAY_OF_YEAR)

        val dayCourses = mutableListOf<JSONObject>()
        val cal = Calendar.getInstance()

        for (i in 0 until courses.length()) {
            val c = courses.getJSONObject(i)
            val st = c.optLong("startTime", 0L)
            cal.timeInMillis = st
            if (cal.get(Calendar.YEAR) == targetDayYear && cal.get(Calendar.DAY_OF_YEAR) == targetDayOfYear) {
                dayCourses.add(c)
            }
        }

        if (dayCourses.isEmpty()) return null
        dayCourses.sortBy { it.optLong("startTime", 0L) }

        // 如果是今天：根据当前时间挑选正在上课或即将开始的课程
        if (dayOffset == 0) {
            // 1. 查找正在进行的课程
            for (c in dayCourses) {
                val st = c.optLong("startTime", 0L)
                val et = c.optLong("endTime", 0L)
                if (st <= now && et > now) {
                    val totalMs = (et - st).toDouble()
                    val elapsedMs = (now - st).toDouble()
                    val progress = if (totalMs > 0) ((elapsedMs / totalMs) * 100).toInt().coerceIn(0, 100) else 0
                    return WidgetCourseData(
                        name = c.optString("name", "课程"),
                        location = c.optString("location", ""),
                        teacher = c.optString("teacher", ""),
                        startTime = st,
                        endTime = et,
                        statusText = "正在上课",
                        statusColor = Color(0xFFFF5252),
                        progressPercent = progress,
                        isOngoing = true
                    )
                }
            }

            // 2. 查找今天尚未开始的第一节课
            for (c in dayCourses) {
                val st = c.optLong("startTime", 0L)
                val et = c.optLong("endTime", 0L)
                if (st > now) {
                    val diffMin = ((st - now) / 60000).toInt()
                    val statusText = if (diffMin <= 10) "马上开始" else if (diffMin <= 45) "即将开始" else "下节课"
                    val statusColor = if (diffMin <= 10) Color(0xFFFF5252) else if (diffMin <= 45) Color(0xFFFFA000) else Color(0xFF64B5F6)
                    return WidgetCourseData(
                        name = c.optString("name", "课程"),
                        location = c.optString("location", ""),
                        teacher = c.optString("teacher", ""),
                        startTime = st,
                        endTime = et,
                        statusText = statusText,
                        statusColor = statusColor,
                        progressPercent = 0,
                        isOngoing = false
                    )
                }
            }

            // 今天课程全部结束
            return null
        } else {
            // 非今天的目标日期：展示当天第一节课
            val first = dayCourses.first()
            val st = first.optLong("startTime", 0L)
            val et = first.optLong("endTime", 0L)
            return WidgetCourseData(
                name = first.optString("name", "课程"),
                location = first.optString("location", ""),
                teacher = first.optString("teacher", ""),
                startTime = st,
                endTime = et,
                statusText = "当天首节",
                statusColor = Color(0xFF64B5F6),
                progressPercent = 0,
                isOngoing = false
            )
        }
    }
}
