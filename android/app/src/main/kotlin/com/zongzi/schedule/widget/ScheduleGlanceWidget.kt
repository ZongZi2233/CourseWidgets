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
        val dateDisplay = when (dayOffset) {
            0 -> "今天 · ${monthDayFmt.format(targetDate)}"
            1 -> "明天 · ${monthDayFmt.format(targetDate)}"
            -1 -> "昨天 · ${monthDayFmt.format(targetDate)}"
            else -> "${weekFmt.format(targetDate)} · ${monthDayFmt.format(targetDate)}"
        }

        val courseData = loadTargetCourseData(context, targetCal, dayOffset)

        provideContent {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(ImageProvider(R.drawable.bg_glass_widget))
                    .padding(8.dp)
            ) {
                Column(
                    modifier = GlanceModifier.fillMaxSize()
                ) {
                    // 顶部导航栏：精简日期指示 + 交互切日胶囊 (严密控制尺寸杜绝右侧溢出)
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(bottom = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = dateDisplay,
                            maxLines = 1,
                            style = TextStyle(
                                color = ColorProvider(Color.White),
                                fontWeight = FontWeight.Bold,
                                fontSize = 11.sp
                            )
                        )
                        Spacer(modifier = GlanceModifier.defaultWeight())

                        // 切日前一天 (28×24dp 紧凑轻触胶囊)
                        Box(
                            modifier = GlanceModifier
                                .width(28.dp)
                                .height(24.dp)
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to -1)
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "‹",
                                style = TextStyle(
                                    color = ColorProvider(Color.White),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp
                                )
                            )
                        }
                        Spacer(modifier = GlanceModifier.width(3.dp))

                        // 回到今天
                        Box(
                            modifier = GlanceModifier
                                .width(28.dp)
                                .height(24.dp)
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to 0)
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "今",
                                style = TextStyle(
                                    color = ColorProvider(if (dayOffset == 0) Color(0xFFFF9A9E) else Color.White),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 10.sp
                                )
                            )
                        }
                        Spacer(modifier = GlanceModifier.width(3.dp))

                        // 切日后一天
                        Box(
                            modifier = GlanceModifier
                                .width(28.dp)
                                .height(24.dp)
                                .background(ImageProvider(R.drawable.bg_glass_badge))
                                .clickable(
                                    actionRunCallback<SwitchDayActionCallback>(
                                        actionParametersOf(SwitchDayActionCallback.deltaKey to 1)
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "›",
                                style = TextStyle(
                                    color = ColorProvider(Color.White),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp
                                )
                            )
                        }
                    }

                    // 核心课程卡片内容区：采用 defaultWeight() 杜绝 Column 底部溢出与炸排版！
                    Box(
                        modifier = GlanceModifier
                            .defaultWeight()
                            .fillMaxWidth()
                            .background(ImageProvider(R.drawable.bg_glass_card))
                            .padding(horizontal = 8.dp, vertical = 6.dp)
                            .clickable(actionStartActivity(launchIntent))
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
                                            fontSize = 9.sp
                                        ),
                                        modifier = GlanceModifier
                                            .background(ImageProvider(R.drawable.bg_glass_badge))
                                            .padding(horizontal = 5.dp, vertical = 1.dp)
                                    )
                                    Spacer(modifier = GlanceModifier.defaultWeight())
                                    Text(
                                        text = timeStr,
                                        style = TextStyle(
                                            color = ColorProvider(Color(0xD9FFFFFF)),
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Medium
                                        )
                                    )
                                }

                                Spacer(modifier = GlanceModifier.height(3.dp))

                                // 课程名称 (单行省略，杜绝双行高度撑爆 2×2 卡片)
                                Text(
                                    text = courseData.name,
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color.White),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 13.sp
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
                                        fontSize = 10.sp
                                    )
                                )

                                // 正在上课时的进度条
                                if (courseData.isOngoing) {
                                    Spacer(modifier = GlanceModifier.height(2.dp))
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
                                        fontSize = 12.sp
                                    )
                                )
                                Spacer(modifier = GlanceModifier.height(2.dp))
                                Text(
                                    text = if (dayOffset == 0) "轻点 › 翻阅明日日程" else "享受自由时光，好好休息吧~",
                                    style = TextStyle(
                                        color = ColorProvider(Color(0x99FFFFFF)),
                                        fontSize = 9.sp
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
            val countDesc = if (dayCourses.size > 1) " · 共${dayCourses.size}节" else ""
            val statusTitle = if (dayOffset > 0) "当天首节$countDesc" else "历史课程$countDesc"
            return WidgetCourseData(
                name = first.optString("name", "课程"),
                location = first.optString("location", ""),
                teacher = first.optString("teacher", ""),
                startTime = st,
                endTime = et,
                statusText = statusTitle,
                statusColor = if (dayOffset > 0) Color(0xFF64B5F6) else Color(0xFFB0BEC5),
                progressPercent = 0,
                isOngoing = false
            )
        }
    }
}
