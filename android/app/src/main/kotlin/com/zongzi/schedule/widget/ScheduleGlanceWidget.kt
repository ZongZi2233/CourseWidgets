package com.zongzi.schedule.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
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
 * [v3.1.0] CourseWidgets 旗舰黑曜石磨砂课程小组件 (基于 Jetpack Glance 1.2.0)
 * 视觉与交互特性：
 * 1. 绑定 PreferencesGlanceStateDefinition，在 provideContent 内响应式读取 dayOffset 与 refreshTick，彻底解决按钮点不动与数据不实时刷新的问题；
 * 2. 启用 SizeMode.Exact 精确尺寸感知，顶栏左侧日期使用 defaultWeight() 弹性自适应，彻底根治 2×2 尺寸下右侧切日按钮溢出；
 * 3. 采用高不透明度黑曜石微晶磨砂底板 + 莫奈暗色高级配色（薄荷绿 #8AE29A / 暖金 #F2CE69 / 玫瑰粉 #EB7A99 / 冰川蓝 #8AB4F8）+ 矢量多节点时间轴。
 */
class ScheduleGlanceWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition
    override val sizeMode: SizeMode = SizeMode.Exact

    data class WidgetCourseData(
        val name: String,
        val location: String,
        val teacher: String,
        val startTime: Long,
        val endTime: Long,
        val statusText: String,
        val statusColor: Color,
        val statusColorArgb: Int,
        val progressPercent: Int,
        val isOngoing: Boolean,
        val currentIdx: Int = 0,
        val totalCount: Int = 1,
        val nextHint: String? = null
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val glancePrefs = currentState<Preferences>()
            val fallbackSp = context.getSharedPreferences(SwitchDayActionCallback.PREFS_NAME, Context.MODE_PRIVATE)
            val dayOffset = glancePrefs[SwitchDayActionCallback.GLANCE_KEY_DAY_OFFSET]
                ?: fallbackSp.getInt(SwitchDayActionCallback.KEY_DAY_OFFSET, 0)
            // 订阅 refreshTick 以确保广播/后台更新强制触发 Composable 重组
            val refreshTick = glancePrefs[SwitchDayActionCallback.GLANCE_KEY_REFRESH_TICK] ?: 0L

            val size = LocalSize.current
            val isCompactWidth = size.width > 0.dp && size.width < 185.dp

            val targetCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }
            val targetDate = targetCal.time

            val monthDayFmt = SimpleDateFormat(if (isCompactWidth) "M/d" else "M月d日", Locale.CHINA)
            val weekFmt = SimpleDateFormat("E", Locale.CHINA)
            val dateDisplay = when (dayOffset) {
                0 -> if (isCompactWidth) "今天 ${monthDayFmt.format(targetDate)}" else "今天 · ${monthDayFmt.format(targetDate)}"
                1 -> if (isCompactWidth) "明天 ${monthDayFmt.format(targetDate)}" else "明天 · ${monthDayFmt.format(targetDate)}"
                -1 -> if (isCompactWidth) "昨天 ${monthDayFmt.format(targetDate)}" else "昨天 · ${monthDayFmt.format(targetDate)}"
                else -> if (isCompactWidth) "${weekFmt.format(targetDate)} ${monthDayFmt.format(targetDate)}" else "${weekFmt.format(targetDate)} · ${monthDayFmt.format(targetDate)}"
            }

            val courseData = if (refreshTick >= 0L) {
                loadTargetCourseData(context, targetCal, dayOffset)
            } else {
                null
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            val btnWidth = if (isCompactWidth) 23.dp else 27.dp
            val btnHeight = if (isCompactWidth) 21.dp else 24.dp
            val btnGap = if (isCompactWidth) 2.dp else 3.dp

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(ImageProvider(R.drawable.bg_glass_widget))
                    .padding(if (isCompactWidth) 7.dp else 9.dp)
            ) {
                Column(
                    modifier = GlanceModifier.fillMaxSize()
                ) {
                    // 顶部导航栏：左侧日期 defaultWeight() 自动收缩防溢出 + 右侧紧凑切日胶囊
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(bottom = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = dateDisplay,
                            maxLines = 1,
                            modifier = GlanceModifier.defaultWeight().padding(end = 3.dp),
                            style = TextStyle(
                                color = ColorProvider(Color(0xFFF2F5FA)),
                                fontWeight = FontWeight.Bold,
                                fontSize = if (isCompactWidth) 10.5.sp else 11.5.sp
                            )
                        )

                        // 切日前一天
                        Box(
                            modifier = GlanceModifier
                                .width(btnWidth)
                                .height(btnHeight)
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
                                    color = ColorProvider(Color(0xFFE2E8F0)),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = if (isCompactWidth) 12.sp else 13.sp
                                )
                            )
                        }
                        Spacer(modifier = GlanceModifier.width(btnGap))

                        // 回到今天 (采用莫奈薄荷绿 #8AE29A 高亮)
                        Box(
                            modifier = GlanceModifier
                                .width(btnWidth)
                                .height(btnHeight)
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
                                    color = ColorProvider(if (dayOffset == 0) Color(0xFF8AE29A) else Color(0xFFE2E8F0)),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = if (isCompactWidth) 9.5.sp else 10.sp
                                )
                            )
                        }
                        Spacer(modifier = GlanceModifier.width(btnGap))

                        // 切日后一天
                        Box(
                            modifier = GlanceModifier
                                .width(btnWidth)
                                .height(btnHeight)
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
                                    color = ColorProvider(Color(0xFFE2E8F0)),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = if (isCompactWidth) 12.sp else 13.sp
                                )
                            )
                        }
                    }

                    // 核心课程卡片内容区
                    Box(
                        modifier = GlanceModifier
                            .defaultWeight()
                            .fillMaxWidth()
                            .background(ImageProvider(R.drawable.bg_glass_card))
                            .padding(horizontal = 9.dp, vertical = 7.dp)
                            .clickable(actionStartActivity(launchIntent))
                    ) {
                        if (courseData != null) {
                            val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())
                            val timeStr = "${timeFmt.format(Date(courseData.startTime))}-${timeFmt.format(Date(courseData.endTime))}"

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
                                        maxLines = 1,
                                        style = TextStyle(
                                            color = ColorProvider(courseData.statusColor),
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 9.5.sp
                                        ),
                                        modifier = GlanceModifier
                                            .background(ImageProvider(R.drawable.bg_glass_badge))
                                            .padding(horizontal = 5.5.dp, vertical = 1.5.dp)
                                    )
                                    Spacer(modifier = GlanceModifier.defaultWeight())
                                    Text(
                                        text = timeStr,
                                        maxLines = 1,
                                        style = TextStyle(
                                            color = ColorProvider(Color(0xD9F1F5F9)),
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    )
                                }

                                Spacer(modifier = GlanceModifier.height(4.dp))

                                // 课程名称
                                Text(
                                    text = courseData.name,
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color.White),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = if (isCompactWidth) 12.5.sp else 13.5.sp
                                    )
                                )

                                Spacer(modifier = GlanceModifier.defaultWeight())

                                // 教室与下一节提示
                                val roomText = if (courseData.location.isNotEmpty() && !courseData.location.contains("未知")) {
                                    courseData.location
                                } else {
                                    "未指定教室"
                                }
                                val subDetails = if (!courseData.nextHint.isNullOrEmpty() && !isCompactWidth) {
                                    "$roomText · ${courseData.nextHint}"
                                } else if (courseData.teacher.isNotEmpty()) {
                                    "$roomText · ${courseData.teacher}"
                                } else {
                                    roomText
                                }

                                Text(
                                    text = subDetails,
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color(0xB8E2E8F0)),
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                )

                                Spacer(modifier = GlanceModifier.height(4.dp))

                                // 矢量多节点时间轴进度条（与 Android 16 实况通知同款圆点节点设计）
                                val timelineBmp = renderWidgetNodeTimeline(
                                    context = context,
                                    progressPercent = courseData.progressPercent,
                                    activeColor = courseData.statusColorArgb,
                                    currentIdx = courseData.currentIdx,
                                    totalCount = courseData.totalCount,
                                    isOngoing = courseData.isOngoing
                                )
                                Image(
                                    provider = ImageProvider(timelineBmp),
                                    contentDescription = "课程进度轴",
                                    contentScale = ContentScale.FillBounds,
                                    modifier = GlanceModifier.fillMaxWidth().height(10.dp)
                                )
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
                                    text = if (dayOffset == 0) "今日课程已全部结束" else "当天暂无课程安排",
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color(0xFFF1F5F9)),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 11.5.sp
                                    )
                                )
                                Spacer(modifier = GlanceModifier.height(3.dp))
                                Text(
                                    text = if (dayOffset == 0) "点击右上角 › 预览明日课表" else "好好休息，享受自由时光~",
                                    maxLines = 1,
                                    style = TextStyle(
                                        color = ColorProvider(Color(0x99CBD5E1)),
                                        fontSize = 9.5.sp
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

    /**
     * 渲染高清抗锯齿矢量多节点时间轴 Bitmap（带前后课程圆点节点、胶囊轨道与发光进度游标）
     */
    private fun renderWidgetNodeTimeline(
        context: Context,
        progressPercent: Int,
        activeColor: Int,
        currentIdx: Int,
        totalCount: Int,
        isOngoing: Boolean
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val density = dm.density.coerceIn(2.0f, 3.5f)
        val w = (180f * density).toInt()
        val h = (10f * density).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cy = h / 2f

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = 0x2EFFFFFF
        }
        val activePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = activeColor
        }
        val dotDonePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = activeColor
        }
        val dotFuturePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = 0x55FFFFFF
        }

        val dotR = 2.4f * density
        val dotGap = 5.5f * density
        val barH = 3.2f * density
        val barR = barH / 2f

        val pastDots = currentIdx.coerceIn(0, 4)
        val futureDots = (totalCount - 1 - currentIdx).coerceIn(0, 4)

        var leftX = dotR + 1f * density
        for (i in 0 until pastDots) {
            canvas.drawCircle(leftX, cy, dotR, dotDonePaint)
            leftX += dotR * 2 + dotGap
        }

        var rightX = w - dotR - 1f * density
        for (i in 0 until futureDots) {
            canvas.drawCircle(rightX, cy, dotR, dotFuturePaint)
            rightX -= dotR * 2 + dotGap
        }

        val barStart = if (pastDots > 0) leftX + 1f * density else 2f * density
        val barEnd = if (futureDots > 0) rightX - 1f * density else w - 2f * density

        if (barEnd > barStart + 8f * density) {
            // 轨道底色
            canvas.drawRoundRect(
                RectF(barStart, cy - barR, barEnd, cy + barR),
                barR,
                barR,
                trackPaint
            )

            // 起止端点微节点
            canvas.drawCircle(barStart + barR, cy, barR * 1.15f, if (isOngoing) activePaint else dotFuturePaint)
            canvas.drawCircle(barEnd - barR, cy, barR * 1.15f, dotFuturePaint)

            if (isOngoing) {
                val frac = (progressPercent / 100f).coerceIn(0.05f, 1.0f)
                val fillEnd = barStart + (barEnd - barStart) * frac
                canvas.drawRoundRect(
                    RectF(barStart, cy - barR, fillEnd, cy + barR),
                    barR,
                    barR,
                    activePaint
                )

                // 发光进度游标节点
                val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = (activeColor and 0x00FFFFFF) or 0x55000000
                }
                canvas.drawCircle(fillEnd, cy, 4.2f * density, glowPaint)
                val cursorPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = 0xFFFFFFFF.toInt()
                }
                canvas.drawCircle(fillEnd, cy, 2.3f * density, cursorPaint)
            }
        }

        return bmp
    }

    private fun loadTargetCourseData(
        context: Context,
        targetCal: Calendar,
        dayOffset: Int
    ): WidgetCourseData? {
        val prefs = context.getSharedPreferences(LiveUpdateNotificationManager.PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(LiveUpdateNotificationManager.KEY_UPCOMING_COURSES, null) ?: return null
        val courses = try {
            JSONArray(jsonStr)
        } catch (_: Exception) {
            return null
        }
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

        if (dayOffset == 0) {
            // 1. 查找正在进行的课程
            for (idx in dayCourses.indices) {
                val c = dayCourses[idx]
                val st = c.optLong("startTime", 0L)
                val et = c.optLong("endTime", 0L)
                if (st <= now && et > now) {
                    val totalMs = (et - st).toDouble()
                    val elapsedMs = (now - st).toDouble()
                    val progress = if (totalMs > 0) ((elapsedMs / totalMs) * 100).toInt().coerceIn(0, 100) else 0
                    val remMin = ((et - now) / 60000).toInt().coerceAtLeast(1)
                    val nextHint = if (idx + 1 < dayCourses.size) {
                        "下节: ${dayCourses[idx + 1].optString("name", "")}"
                    } else {
                        "今日最后一节"
                    }
                    cal.timeInMillis = st
                    val isEvening = cal.get(Calendar.HOUR_OF_DAY) >= 18
                    // 与参考图一致：日间课采用莫奈薄荷绿 #8AE29A，晚间课采用暖金 #F2CE69
                    val argb = if (isEvening) 0xFFF2CE69.toInt() else 0xFF8AE29A.toInt()
                    return WidgetCourseData(
                        name = c.optString("name", "课程"),
                        location = c.optString("location", ""),
                        teacher = c.optString("teacher", ""),
                        startTime = st,
                        endTime = et,
                        statusText = "上课中 · 剩${remMin}分",
                        statusColor = Color(argb),
                        statusColorArgb = argb,
                        progressPercent = progress,
                        isOngoing = true,
                        currentIdx = idx,
                        totalCount = dayCourses.size,
                        nextHint = nextHint
                    )
                }
            }

            // 2. 查找今天尚未开始的第一节课
            for (idx in dayCourses.indices) {
                val c = dayCourses[idx]
                val st = c.optLong("startTime", 0L)
                val et = c.optLong("endTime", 0L)
                if (st > now) {
                    val diffMin = ((st - now) / 60000).toInt()
                    val statusText = when {
                        diffMin <= 15 -> "${diffMin}分后上课"
                        diffMin <= 45 -> "课间 · ${diffMin}分后"
                        else -> "待上课 · 共${dayCourses.size - idx}节"
                    }
                    // 课间/即将上课采用参考图同款玫瑰粉 #EB7A99，远期预告采用柔和冰川蓝 #8AB4F8
                    val argb = when {
                        diffMin <= 45 -> 0xFFEB7A99.toInt()
                        else -> 0xFF8AB4F8.toInt()
                    }
                    val prevEnd = if (idx > 0) dayCourses[idx - 1].optLong("endTime", st - 600_000L) else st - 1800_000L
                    val breakTotal = (st - prevEnd).coerceAtLeast(60_000L).toDouble()
                    val breakProg = if (diffMin <= 45) {
                        (((now - prevEnd).toDouble() / breakTotal) * 100).toInt().coerceIn(8, 95)
                    } else 0

                    return WidgetCourseData(
                        name = c.optString("name", "课程"),
                        location = c.optString("location", ""),
                        teacher = c.optString("teacher", ""),
                        startTime = st,
                        endTime = et,
                        statusText = statusText,
                        statusColor = Color(argb),
                        statusColorArgb = argb,
                        progressPercent = breakProg,
                        isOngoing = diffMin <= 45,
                        currentIdx = idx,
                        totalCount = dayCourses.size
                    )
                }
            }

            return null
        } else {
            val first = dayCourses.first()
            val st = first.optLong("startTime", 0L)
            val et = first.optLong("endTime", 0L)
            val countDesc = if (dayCourses.size > 1) " · 共${dayCourses.size}节" else ""
            val statusTitle = if (dayOffset > 0) "首节$countDesc" else "历史$countDesc"
            val argb = if (dayOffset > 0) 0xFF8AB4F8.toInt() else 0xFF94A3B8.toInt()
            return WidgetCourseData(
                name = first.optString("name", "课程"),
                location = first.optString("location", ""),
                teacher = first.optString("teacher", ""),
                startTime = st,
                endTime = et,
                statusText = statusTitle,
                statusColor = Color(argb),
                statusColorArgb = argb,
                progressPercent = 0,
                isOngoing = false,
                currentIdx = 0,
                totalCount = dayCourses.size
            )
        }
    }
}
