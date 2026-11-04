package com.zongzi.schedule

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

object LiveUpdateNotificationManager {
    // [v3.1.0] 升级全新高优先级通道 ID，彻底重置系统通知降级缓存，保障 Android 16 实况胶囊与锁屏卡片 100% 置顶展示
    const val CHANNEL_ID = "live_course_updates_v4"
    const val NOTIFICATION_ID = 1000
    const val REMINDER_CHANNEL_ID = "course_reminders"
    const val REMINDER_NOTIFICATION_ID = 1001
    const val PREFS_NAME = "cw_live_update_prefs"
    const val KEY_UPCOMING_COURSES = "upcoming_courses_json"
    const val KEY_CURRENT_WEEK = "current_week"
    const val KEY_SEMESTER_START_MS = "semester_start_ms"
    const val KEY_PROGRESS_STYLE = "live_progress_style"

    const val STYLE_CENTERED_DOTS = "centered_dots"
    const val STYLE_DURATION_SEGMENTS = "duration_segments"

    private data class ParsedCourse(
        val name: String,
        val location: String,
        val teacher: String,
        val startTime: Long,
        val endTime: Long,
        val startSection: Int,
        val endSection: Int
    )

    data class TimelineSegment(
        val weight: Float,
        val isBreak: Boolean = false
    )

    private data class LiveUpdateSnapshot(
        val headerSubText: String,
        val shortCapsuleText: String,
        val heroTitleSpan: CharSequence,
        val detailBodySpan: CharSequence,
        val smallIconRes: Int,
        val accentColor: Int,
        val trackColor: Int,
        val isOngoingClass: Boolean,
        val targetWhenMs: Long?,
        val usesChronometer: Boolean,
        val isCountDown: Boolean,
        val segments: List<TimelineSegment>,
        val activeIndex: Int,
        val progressFraction: Float,
        val progressStyleMode: String
    )

    private fun SpannableStringBuilder.appendStyled(
        text: String,
        relativeSize: Float = 1.0f,
        color: Int? = null,
        bold: Boolean = false
    ): SpannableStringBuilder {
        if (text.isEmpty()) return this
        val start = length
        append(text)
        val end = length
        val flags = Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        if (relativeSize != 1.0f) {
            setSpan(RelativeSizeSpan(relativeSize), start, end, flags)
        }
        if (color != null) {
            setSpan(ForegroundColorSpan(color), start, end, flags)
        }
        if (bold) {
            setSpan(StyleSpan(Typeface.BOLD), start, end, flags)
        }
        return this
    }

    /**
     * 发送高优先级主动唤醒课程提醒通知（含声音、振动、横幅弹窗与亮屏）
     */
    fun postReminderAlert(
        context: Context,
        title: String,
        body: String,
        courseName: String,
        location: String,
        startTime: Long
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                REMINDER_CHANNEL_ID,
                "课程即将开始提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "课程即将开始的高优先级强提醒（响铃与振动）"
                setShowBadge(true)
                enableLights(true)
                lightColor = 0xFFFF5252.toInt()
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 350, 150, 350)
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                REMINDER_NOTIFICATION_ID,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, REMINDER_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder.setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_course)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
            builder.setFullScreenIntent(pendingIntent, false)
        }

        try {
            val appIconBitmap =
                BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
            if (appIconBitmap != null) {
                builder.setLargeIcon(appIconBitmap)
            }
        } catch (_: Exception) {
        }

        notificationManager.notify(REMINDER_NOTIFICATION_ID, builder.build())
        Log.d("CourseWidgets", "🔔 [LiveUpdate] 已发送主动唤醒提醒通知: $title - $courseName")
    }

    /**
     * [v3.1.0] 原生 Android 16 Live Update (Notification.ProgressStyle) 实时通知引擎
     * 严禁使用 setCustomContentView / setCustomBigContentView (RemoteViews)，
     * 确保 Android 16 Notification.hasPromotableCharacteristics() 100% 通过，
     * 完整激活状态栏实时胶囊、锁屏实况卡片与置顶展开态分段/圆点节点进度条！
     */
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
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 移除旧版可能被系统降级的通道
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                notificationManager.deleteNotificationChannel("live_course_updates_v3")
            } catch (_: Exception) {
            }
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程实时实况 (Live Updates)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Android 16 Live Updates 课程多节点进度与状态栏胶囊"
                setShowBadge(true)
                enableLights(true)
                lightColor = 0xFF8AE29A.toInt()
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(false)
                }
            }
            notificationManager.createNotificationChannel(channel)
        }

        val snapshot = buildSnapshotFromPrefs(
            context = context,
            fallbackTitle = title,
            fallbackBody = body,
            fallbackSubLocation = subLocation,
            fallbackProgress = progress,
            fallbackMax = maxProgress,
            fallbackWhenTime = whenTime,
            fallbackUsesChronometer = usesChronometer,
            fallbackIsCountingDown = isCountingDown
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val titleSpan = snapshot.heroTitleSpan
        val bodySpan = snapshot.detailBodySpan

        builder.setSmallIcon(snapshot.smallIconRes)
        builder.setColor(snapshot.accentColor)
        builder.setContentTitle(titleSpan)
        builder.setContentText(bodySpan)
        builder.setSubText(snapshot.headerSubText)
        builder.setOngoing(true)
        builder.setOnlyAlertOnce(true)
        builder.setAutoCancel(false)
        builder.setCategory(Notification.CATEGORY_PROGRESS)
        builder.setVisibility(Notification.VISIBILITY_PUBLIC)
        @Suppress("DEPRECATION")
        builder.setPriority(Notification.PRIORITY_MAX)

        // 状态栏胶囊短文本（Android 16 Promoted Ongoing 胶囊核心文字）
        val capsuleText = snapshot.shortCapsuleText.ifEmpty { subLocation ?: "课表实况" }
        builder.setTicker(capsuleText)
        try {
            builder.setShortCriticalText(capsuleText)
        } catch (_: Throwable) {
            try {
                val method = builder.javaClass.getMethod(
                    "setShortCriticalText",
                    CharSequence::class.java
                )
                method.invoke(builder, capsuleText)
            } catch (_: Throwable) {
            }
        }

        // 绑定系统硬件级倒计时秒表 Chronometer
        if (snapshot.targetWhenMs != null && snapshot.targetWhenMs > 0L) {
            builder.setWhen(snapshot.targetWhenMs)
            builder.setShowWhen(true)
            builder.setUsesChronometer(snapshot.usesChronometer)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(snapshot.isCountDown)
            }
        } else {
            builder.setShowWhen(false)
            builder.setUsesChronometer(false)
        }

        // 构建 Android 16 原生 Notification.ProgressStyle（多节点 + 双模式分段 + 矢量小怪兽/行走小人 TrackerIcon）
        var progressStyleApplied = false
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                val progressStyle = buildNativeAndroid16ProgressStyle(context, snapshot)
                builder.setStyle(progressStyle)
                progressStyleApplied = true
            } catch (e: Exception) {
                Log.e("CourseWidgets", "应用 Android 16 ProgressStyle 失败，回退 BigTextStyle: ${e.message}", e)
            }
        }

        if (!progressStyleApplied) {
            val pct = (snapshot.progressFraction * 100f).toInt().coerceIn(0, 100)
            builder.setProgress(100, pct, false)
            builder.setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(titleSpan)
                    .bigText(bodySpan)
                    .setSummaryText(snapshot.headerSubText)
            )
        }

        // Android 16 Live Update (Promoted Ongoing) 提权标志 + 隐藏左上角冗余软件名称
        val extras = android.os.Bundle()
        extras.putBoolean("android.requestPromotedOngoing", true)
        extras.putString("android.substName", "\u200B")
        builder.addExtras(extras)

        try {
            builder.setRequestPromotedOngoing(true)
        } catch (_: Throwable) {
            try {
                val method = builder.javaClass.getMethod(
                    "setRequestPromotedOngoing",
                    Boolean::class.javaPrimitiveType
                )
                method.invoke(builder, true)
            } catch (_: Throwable) {
            }
        }

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
            notification.flags = notification.flags or Notification.FLAG_PROMOTED_ONGOING
        } catch (_: Throwable) {
        }

        notificationManager.notify(id, notification)
    }

    /**
     * 构建 Android 16 原生 Notification.ProgressStyle：
     * - 恢复粗胶囊轨道 + 圆点节点（Point）+ 矢量游标（TrackerIcon）：
     *   在 Android 16 SystemUI 中，必须添加 ProgressStyle.Point 或 TrackerIcon 并使用显式已走/未走颜色分段
     *   （setStyledByProgress(false)），系统才会渲染 8~10dp 粗胶囊轨道与圆点节点；
     * - 支持「居中圆点样式 (centered_dots)」与「按时长分段样式 (duration_segments)」，
     *   严格保持 1 节课 = 1 个课节节点。
     */
    private fun buildNativeAndroid16ProgressStyle(
        context: Context,
        snapshot: LiveUpdateSnapshot
    ): Notification.ProgressStyle {
        val style = Notification.ProgressStyle()
        val totalCount = snapshot.segments.size.coerceAtLeast(1)
        val safeActive = snapshot.activeIndex.coerceIn(0, totalCount - 1)
        val clampedProgress = snapshot.progressFraction.coerceIn(0f, 1f)

        val pastColor = 0xFF7A818E.toInt()
        val futureColor = 0xFF3A3F4B.toInt()

        var cumulativePos = 0
        var trackerProgressPos = 0

        if (totalCount <= 1) {
            val totalLen = 180
            val filledLen = (totalLen * clampedProgress).toInt().coerceIn(8, totalLen - 8)
            val remainLen = (totalLen - filledLen).coerceAtLeast(8)
            style.addProgressSegment(
                Notification.ProgressStyle.Segment(filledLen)
                    .setColor(snapshot.accentColor)
                    .setId(1)
            )
            style.addProgressSegment(
                Notification.ProgressStyle.Segment(remainLen)
                    .setColor(snapshot.trackColor)
                    .setId(2)
            )
            trackerProgressPos = filledLen
            style.addProgressPoint(
                Notification.ProgressStyle.Point(totalLen)
                    .setColor(snapshot.accentColor)
                    .setId(1)
            )
        } else if (snapshot.progressStyleMode == STYLE_CENTERED_DOTS) {
            // 居中圆点粗轨道样式：
            // 当前课居中展开为粗胶囊长条，前后其余课程为圆点节点（Point）+ 紧凑胶囊段
            val sideSegLen = 28
            val centerPillLen = 160
            var segmentId = 1

            for (i in 0 until totalCount) {
                when {
                    i < safeActive -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(sideSegLen)
                                .setColor(pastColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += sideSegLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(pastColor)
                                .setId(i + 1)
                        )
                    }
                    i == safeActive -> {
                        val filledLen = (centerPillLen * clampedProgress).toInt().coerceIn(12, centerPillLen - 12)
                        val remainLen = (centerPillLen - filledLen).coerceAtLeast(12)
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(filledLen)
                                .setColor(snapshot.accentColor)
                                .setId(segmentId++)
                        )
                        trackerProgressPos = cumulativePos + filledLen
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(remainLen)
                                .setColor(snapshot.trackColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += centerPillLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(snapshot.accentColor)
                                .setId(i + 1)
                        )
                    }
                    else -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(sideSegLen)
                                .setColor(futureColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += sideSegLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(futureColor)
                                .setId(i + 1)
                        )
                    }
                }
            }
        } else {
            // 按时长分段粗轨道样式：
            // 每节课对应 1 个按真实时长比例缩放的粗胶囊段 + 课节圆点节点（Point）
            var segmentId = 1
            for (i in 0 until totalCount) {
                val segLen = snapshot.segments[i].weight.toInt().coerceIn(40, 120)
                when {
                    i < safeActive -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(segLen)
                                .setColor(pastColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += segLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(pastColor)
                                .setId(i + 1)
                        )
                    }
                    i == safeActive -> {
                        val filledLen = (segLen * clampedProgress).toInt().coerceIn(10, segLen - 10)
                        val remainLen = (segLen - filledLen).coerceAtLeast(10)
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(filledLen)
                                .setColor(snapshot.accentColor)
                                .setId(segmentId++)
                        )
                        trackerProgressPos = cumulativePos + filledLen
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(remainLen)
                                .setColor(snapshot.trackColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += segLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(snapshot.accentColor)
                                .setId(i + 1)
                        )
                    }
                    else -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(segLen)
                                .setColor(futureColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += segLen
                        style.addProgressPoint(
                            Notification.ProgressStyle.Point(cumulativePos)
                                .setColor(futureColor)
                                .setId(i + 1)
                        )
                    }
                }
            }
        }

        style.setStyledByProgress(false)
        style.setProgress(trackerProgressPos)
        style.setProgressIndeterminate(false)

        val trackerIcon = createVectorTrackerIcon(
            context = context,
            drawableRes = snapshot.smallIconRes,
            accentColor = snapshot.accentColor
        )
        if (trackerIcon != null) {
            style.setProgressTrackerIcon(trackerIcon)
        }

        return style
    }

    /**
     * 将矢量图标 (ic_live_monster / ic_live_walker) 按设备真实物理 DPI 渲染为带高对比暗色圆底的精致游标 Icon
     */
    private fun createVectorTrackerIcon(
        context: Context,
        drawableRes: Int,
        accentColor: Int
    ): Icon? {
        return try {
            val density = context.resources.displayMetrics.density.coerceIn(2.5f, 4.0f)
            val sizePx = (26f * density).toInt()
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)

            val cx = sizePx / 2f
            val cy = sizePx / 2f
            val radius = sizePx / 2f - 1f * density

            // 1. 深色高对比圆形底座
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = 0xFF121318.toInt()
            }
            canvas.drawCircle(cx, cy, radius, bgPaint)

            // 2. 主题色发光细描边环
            val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.4f * density
                color = accentColor
            }
            canvas.drawCircle(cx, cy, radius, strokePaint)

            // 3. 居中绘制純矢量小怪兽 / 行走小人
            val drawable = ContextCompat.getDrawable(context, drawableRes)?.mutate()
            if (drawable != null) {
                val pad = (5.2f * density).toInt()
                drawable.setBounds(pad, pad, sizePx - pad, sizePx - pad)
                drawable.colorFilter = PorterDuffColorFilter(accentColor, PorterDuff.Mode.SRC_IN)
                drawable.draw(canvas)
            }

            Icon.createWithBitmap(bmp)
        } catch (e: Exception) {
            Log.e("CourseWidgets", "创建矢量 TrackerIcon 失败: ${e.message}")
            null
        }
    }

    /**
     * 从本地 SharedPreferences 构建参考图同款信息层级的 LiveUpdateSnapshot
     */
    private fun buildSnapshotFromPrefs(
        context: Context,
        fallbackTitle: String,
        fallbackBody: String,
        fallbackSubLocation: String?,
        fallbackProgress: Int,
        fallbackMax: Int,
        fallbackWhenTime: Long?,
        fallbackUsesChronometer: Boolean,
        fallbackIsCountingDown: Boolean
    ): LiveUpdateSnapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val jsonStr = prefs.getString(KEY_UPCOMING_COURSES, null)
        val progressStyleMode = prefs.getString(KEY_PROGRESS_STYLE, STYLE_CENTERED_DOTS) ?: STYLE_CENTERED_DOTS
        val weekNumber = resolveCurrentWeek(prefs)
        val weekLabel = "第 $weekNumber 周"

        val allCourses = parseCoursesJson(jsonStr)
        val now = System.currentTimeMillis()
        val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())

        val cal = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val todayStart = cal.timeInMillis
        val todayEnd = todayStart + 86_400_000L - 1L

        val todayCourses = allCourses
            .filter { it.startTime in todayStart..todayEnd }
            .sortedBy { it.startTime }

        if (todayCourses.isNotEmpty()) {
            val activeIdx = todayCourses.indexOfFirst { now >= it.startTime && now < it.endTime }
            val nextIdx = todayCourses.indexOfFirst { it.startTime > now }

            if (activeIdx >= 0) {
                // ==================== 状态 A：正在上课 ====================
                val current = todayCourses[activeIdx]
                val nextCourse = if (activeIdx + 1 < todayCourses.size) todayCourses[activeIdx + 1] else null
                val isLastOrEvening = (activeIdx == todayCourses.size - 1 && todayCourses.size >= 2) ||
                    current.startSection >= 9 ||
                    getHourOfDay(current.startTime) >= 18

                val accentHex = if (isLastOrEvening) "#F2CE69" else "#8AE29A"
                val accentColor = if (isLastOrEvening) 0xFFF2CE69.toInt() else 0xFF8AE29A.toInt()
                val trackColor = if (isLastOrEvening) 0xFF4B3F24.toInt() else 0xFF2C4332.toInt()

                val sectionLabel = formatSectionLabel(current)
                val startStr = timeFmt.format(Date(current.startTime))
                val endStr = timeFmt.format(Date(current.endTime))
                val locStr = cleanLocation(current.location, "教室待定")

                val totalMs = max(1L, current.endTime - current.startTime)
                val progressFraction = ((now - current.startTime).toFloat() / totalMs.toFloat()).coerceIn(0.03f, 1f)
                val remainingMin = max(1, ((current.endTime - now + 59_999L) / 60_000L).toInt())

                val nextHintPlain = if (nextCourse != null) {
                    val nextLoc = cleanLocation(nextCourse.location, timeFmt.format(Date(nextCourse.startTime)))
                    "下节 ${nextCourse.name} $nextLoc"
                } else {
                    "今天最后一节"
                }

                val heroTitleSpan = SpannableStringBuilder()
                    .appendStyled("上课 ", relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)
                    .appendStyled(startStr, relativeSize = 1.48f, color = accentColor, bold = true)
                    .appendStyled(" · ", relativeSize = 0.72f, color = 0xFF6E737D.toInt(), bold = false)
                    .appendStyled(endStr, relativeSize = 1.48f, color = accentColor, bold = true)
                    .appendStyled(" 下课", relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)

                // 显著拉大主次字号差距：课程名称放大 1.38x 加粗，教室 1.15x 主题色加粗，下节提示缩小至 0.68x 弱化
                val detailBodySpan = SpannableStringBuilder()
                    .appendStyled(current.name, relativeSize = 1.38f, color = null, bold = true)
                    .appendStyled("  ", relativeSize = 1.0f)
                    .appendStyled(locStr, relativeSize = 1.15f, color = accentColor, bold = true)
                    .appendStyled("   ｜ $nextHintPlain", relativeSize = 0.68f, color = 0xFF8A8F99.toInt(), bold = false)

                val segments = todayCourses.map { c ->
                    val durMin = ((c.endTime - c.startTime) / 60000f).coerceIn(25f, 120f)
                    TimelineSegment(weight = durMin, isBreak = false)
                }

                return LiveUpdateSnapshot(
                    headerSubText = "$sectionLabel · $weekLabel",
                    shortCapsuleText = "剩${remainingMin}分",
                    heroTitleSpan = heroTitleSpan,
                    detailBodySpan = detailBodySpan,
                    smallIconRes = R.drawable.ic_live_monster,
                    accentColor = accentColor,
                    trackColor = trackColor,
                    isOngoingClass = true,
                    targetWhenMs = current.endTime,
                    usesChronometer = true,
                    isCountDown = true,
                    segments = segments,
                    activeIndex = activeIdx,
                    progressFraction = progressFraction,
                    progressStyleMode = progressStyleMode
                )
            } else if (nextIdx >= 0) {
                // ==================== 状态 B：课间休息 / 待上课 ====================
                val nextCourse = todayCourses[nextIdx]
                val prevCourse = if (nextIdx > 0) todayCourses[nextIdx - 1] else null

                val accentColor = 0xFFEB7A99.toInt()
                val trackColor = 0xFF562939.toInt()

                val sectionLabel = formatSectionLabel(nextCourse)
                val breakStartMs = prevCourse?.endTime ?: max(todayStart, nextCourse.startTime - 45 * 60_000L)
                val breakStartStr = if (prevCourse != null) {
                    timeFmt.format(Date(prevCourse.endTime))
                } else {
                    timeFmt.format(Date(now))
                }
                val nextStartStr = timeFmt.format(Date(nextCourse.startTime))
                val nextLoc = cleanLocation(nextCourse.location, "教室待定")

                val totalBreakMs = max(1L, nextCourse.startTime - breakStartMs)
                val progressFraction = ((now - breakStartMs).toFloat() / totalBreakMs.toFloat()).coerceIn(0.05f, 1f)
                val diffMin = max(1, ((nextCourse.startTime - now + 59_999L) / 60_000L).toInt())

                val leftTag = if (prevCourse != null) "课间 " else "待上 "
                val heroTitleSpan = SpannableStringBuilder()
                    .appendStyled(leftTag, relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)
                    .appendStyled(breakStartStr, relativeSize = 1.36f, color = 0xFFD0D4DE.toInt(), bold = true)
                    .appendStyled(" · ", relativeSize = 0.72f, color = 0xFF6E737D.toInt(), bold = false)
                    .appendStyled(nextStartStr, relativeSize = 1.48f, color = accentColor, bold = true)
                    .appendStyled(" 上课", relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)

                val breakSubHint = if (prevCourse != null) {
                    "上节 ${prevCourse.name}"
                } else {
                    "今日共 ${todayCourses.size} 节"
                }
                val detailBodySpan = SpannableStringBuilder()
                    .appendStyled(nextCourse.name, relativeSize = 1.38f, color = null, bold = true)
                    .appendStyled("  ", relativeSize = 1.0f)
                    .appendStyled(nextLoc, relativeSize = 1.15f, color = accentColor, bold = true)
                    .appendStyled("   ｜ $breakSubHint", relativeSize = 0.68f, color = 0xFF8A8F99.toInt(), bold = false)

                // 严格按今日真实课程数生成分段（不插入虚拟课间段），当前高亮指向即将上课的 nextIdx
                val segments = todayCourses.map { c ->
                    val durMin = ((c.endTime - c.startTime) / 60000f).coerceIn(28f, 120f)
                    TimelineSegment(weight = durMin, isBreak = false)
                }

                val shortCapsule = if (diffMin <= 60) "${diffMin}分后" else nextStartStr

                return LiveUpdateSnapshot(
                    headerSubText = "$sectionLabel · $weekLabel",
                    shortCapsuleText = shortCapsule,
                    heroTitleSpan = heroTitleSpan,
                    detailBodySpan = detailBodySpan,
                    smallIconRes = R.drawable.ic_live_walker,
                    accentColor = accentColor,
                    trackColor = trackColor,
                    isOngoingClass = false,
                    targetWhenMs = nextCourse.startTime,
                    usesChronometer = diffMin <= 90,
                    isCountDown = true,
                    segments = segments,
                    activeIndex = nextIdx,
                    progressFraction = progressFraction,
                    progressStyleMode = progressStyleMode
                )
            }
        }

        // ==================== 状态 C：今日课程已结束或无课（展示后续预告） ====================
        val futureCourse = allCourses.filter { it.startTime > now }.minByOrNull { it.startTime }
        val accentColor = 0xFF8AE29A.toInt()
        val trackColor = 0xFF2C4332.toInt()

        if (futureCourse != null) {
            val startStr = timeFmt.format(Date(futureCourse.startTime))
            val endStr = timeFmt.format(Date(futureCourse.endTime))
            val relDay = formatRelativeDay(futureCourse.startTime, now)
            val locStr = cleanLocation(futureCourse.location, "教室待定")
            val sectionLabel = formatSectionLabel(futureCourse)

            // 统计目标日期总节数
            val targetCal = Calendar.getInstance().apply {
                timeInMillis = futureCourse.startTime
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val tStart = targetCal.timeInMillis
            val tEnd = tStart + 86_400_000L - 1L
            val targetDayCourses = allCourses.filter { it.startTime in tStart..tEnd }
            val segs = if (targetDayCourses.isNotEmpty()) {
                targetDayCourses.map { c ->
                    TimelineSegment(((c.endTime - c.startTime) / 60000f).coerceIn(28f, 120f))
                }
            } else {
                listOf(TimelineSegment(45f), TimelineSegment(45f))
            }

            val heroTitleSpan = SpannableStringBuilder()
                .appendStyled("$relDay ", relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)
                .appendStyled(startStr, relativeSize = 1.48f, color = accentColor, bold = true)
                .appendStyled(" · ", relativeSize = 0.72f, color = 0xFF6E737D.toInt(), bold = false)
                .appendStyled(endStr, relativeSize = 1.36f, color = 0xFF9E9EA6.toInt(), bold = true)
                .appendStyled(" 下课", relativeSize = 0.68f, color = 0xFF9EA4B0.toInt(), bold = false)

            val detailBodySpan = SpannableStringBuilder()
                .appendStyled(futureCourse.name, relativeSize = 1.38f, color = null, bold = true)
                .appendStyled("  ", relativeSize = 1.0f)
                .appendStyled(locStr, relativeSize = 1.15f, color = accentColor, bold = true)
                .appendStyled("   ｜ 今日课程已结束", relativeSize = 0.68f, color = 0xFF8A8F99.toInt(), bold = false)

            return LiveUpdateSnapshot(
                headerSubText = "$relDay · $sectionLabel · $weekLabel",
                shortCapsuleText = "$relDay${targetDayCourses.size.coerceAtLeast(1)}节",
                heroTitleSpan = heroTitleSpan,
                detailBodySpan = detailBodySpan,
                smallIconRes = R.drawable.ic_live_walker,
                accentColor = accentColor,
                trackColor = trackColor,
                isOngoingClass = false,
                targetWhenMs = null,
                usesChronometer = false,
                isCountDown = false,
                segments = segs,
                activeIndex = 0,
                progressFraction = 0.0f,
                progressStyleMode = progressStyleMode
            )
        }

        val pct = if (fallbackMax > 0) (fallbackProgress.toFloat() / fallbackMax).coerceIn(0f, 1f) else 1f
        val fallbackTitleSpan = SpannableStringBuilder()
            .appendStyled(fallbackTitle.ifEmpty { "今日无课 · 轻松休息" }, relativeSize = 1.25f, bold = true)
        val fallbackBodySpan = SpannableStringBuilder()
            .appendStyled(fallbackBody.ifEmpty { "课程表全天候实时同步中，点击查看完整课表" }, relativeSize = 0.85f, color = 0xFF9EA4B0.toInt())

        return LiveUpdateSnapshot(
            headerSubText = weekLabel,
            shortCapsuleText = fallbackSubLocation ?: "今日无课",
            heroTitleSpan = fallbackTitleSpan,
            detailBodySpan = fallbackBodySpan,
            smallIconRes = R.drawable.ic_live_monster,
            accentColor = accentColor,
            trackColor = trackColor,
            isOngoingClass = false,
            targetWhenMs = fallbackWhenTime,
            usesChronometer = fallbackUsesChronometer,
            isCountDown = fallbackIsCountingDown,
            segments = listOf(TimelineSegment(100f)),
            activeIndex = 0,
            progressFraction = pct,
            progressStyleMode = progressStyleMode
        )
    }

    /**
     * 供 Glance 桌面小组件调用的高 DPI 矢量级多节点时间轴绘制方法
     */
    fun renderTimelineBitmap(
        context: Context,
        segments: List<TimelineSegment>,
        activeIndex: Int,
        progressFraction: Float,
        accentColor: Int,
        trackColor: Int,
        style: String,
        heightDp: Float = 8f,
        widthDp: Float = 220f
    ): Bitmap {
        val density = context.resources.displayMetrics.density.coerceIn(2.5f, 4.0f)
        val widthPx = (widthDp * density).toInt()
        val heightPx = max(14, (heightDp * density).toInt())

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            isDither = true
            isFilterBitmap = true
        }

        val totalCount = segments.size
        val barH = heightPx.toFloat()
        val radius = barH / 2f
        val gap = 5.5f * density

        val pastColor = 0xFF5A5E68.toInt()
        val futureColor = 0xFF32353E.toInt()
        val safeActive = activeIndex.coerceIn(0, max(0, totalCount - 1))
        val clampedProgress = progressFraction.coerceIn(0f, 1f)

        if (totalCount <= 1) {
            paint.color = trackColor
            canvas.drawRoundRect(RectF(0f, 0f, widthPx.toFloat(), barH), radius, radius, paint)
            if (clampedProgress > 0.01f) {
                val fillW = (widthPx * clampedProgress).coerceAtLeast(barH)
                paint.color = accentColor
                canvas.drawRoundRect(RectF(0f, 0f, fillW, barH), radius, radius, paint)
            }
            return bitmap
        }

        if (style == STYLE_CENTERED_DOTS) {
            val dotDiameter = barH
            val dotCount = totalCount - 1
            val totalGapsWidth = (totalCount - 1) * gap
            val pillWidth = max(
                barH * 2.5f,
                widthPx.toFloat() - dotCount * dotDiameter - totalGapsWidth
            )

            var cursorX = 0f
            for (i in 0 until totalCount) {
                if (i < safeActive) {
                    paint.color = pastColor
                    val cx = cursorX + dotDiameter / 2f
                    canvas.drawCircle(cx, barH / 2f, dotDiameter / 2f, paint)
                    cursorX += dotDiameter + gap
                } else if (i == safeActive) {
                    val rect = RectF(cursorX, 0f, cursorX + pillWidth, barH)
                    paint.color = trackColor
                    canvas.drawRoundRect(rect, radius, radius, paint)
                    if (clampedProgress > 0.01f) {
                        val fillW = (pillWidth * clampedProgress).coerceIn(barH, pillWidth)
                        val fillRect = RectF(cursorX, 0f, cursorX + fillW, barH)
                        paint.color = accentColor
                        canvas.drawRoundRect(fillRect, radius, radius, paint)
                    }
                    cursorX += pillWidth + gap
                } else {
                    paint.color = futureColor
                    val cx = cursorX + dotDiameter / 2f
                    canvas.drawCircle(cx, barH / 2f, dotDiameter / 2f, paint)
                    cursorX += dotDiameter + gap
                }
            }
        } else {
            val totalGapsWidth = (totalCount - 1) * gap
            val availWidth = max(barH * totalCount, widthPx.toFloat() - totalGapsWidth)
            val minSegW = barH * 1.8f

            val rawWeights = segments.map { max(15f, it.weight) }
            val weightSum = rawWeights.sum()
            val segWidths = FloatArray(totalCount)
            var usedWidth = 0f
            for (i in 0 until totalCount) {
                segWidths[i] = max(minSegW, availWidth * (rawWeights[i] / weightSum))
                usedWidth += segWidths[i]
            }
            if (usedWidth > 0f) {
                val scale = availWidth / usedWidth
                for (i in 0 until totalCount) {
                    segWidths[i] *= scale
                }
            }

            var cursorX = 0f
            for (i in 0 until totalCount) {
                val w = segWidths[i]
                val rect = RectF(cursorX, 0f, cursorX + w, barH)
                when {
                    i < safeActive -> {
                        paint.color = pastColor
                        canvas.drawRoundRect(rect, radius, radius, paint)
                    }
                    i == safeActive -> {
                        paint.color = trackColor
                        canvas.drawRoundRect(rect, radius, radius, paint)
                        if (clampedProgress > 0.01f) {
                            val fillW = (w * clampedProgress).coerceIn(min(barH, w), w)
                            val fillRect = RectF(cursorX, 0f, cursorX + fillW, barH)
                            paint.color = accentColor
                            canvas.drawRoundRect(fillRect, radius, radius, paint)
                        }
                    }
                    else -> {
                        paint.color = futureColor
                        canvas.drawRoundRect(rect, radius, radius, paint)
                    }
                }
                cursorX += w + gap
            }
        }

        return bitmap
    }

    private fun parseCoursesJson(jsonStr: String?): List<ParsedCourse> {
        if (jsonStr.isNullOrEmpty()) return emptyList()
        val list = mutableListOf<ParsedCourse>()
        try {
            val arr = JSONArray(jsonStr)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val st = obj.optLong("startTime", 0L)
                val et = obj.optLong("endTime", 0L)
                if (st <= 0L || et <= st) continue
                val startSec = obj.optInt("startSection", 0)
                val endSec = obj.optInt("endSection", 0)
                list.add(
                    ParsedCourse(
                        name = obj.optString("name", "课程"),
                        location = obj.optString("location", ""),
                        teacher = obj.optString("teacher", ""),
                        startTime = st,
                        endTime = et,
                        startSection = startSec,
                        endSection = endSec
                    )
                )
            }
        } catch (e: Exception) {
            Log.e("CourseWidgets", "解析 upcoming_courses_json 失败: ${e.message}")
        }
        return list
    }

    fun resolveCurrentWeek(prefs: android.content.SharedPreferences): Int {
        val semesterStartMs = prefs.getLong(KEY_SEMESTER_START_MS, 0L)
        if (semesterStartMs > 0L) {
            val nowCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startCal = Calendar.getInstance().apply {
                timeInMillis = semesterStartMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val diffDays = ((nowCal.timeInMillis - startCal.timeInMillis) / 86_400_000L).toInt()
            if (diffDays >= 0) {
                return (diffDays / 7 + 1).coerceIn(1, 30)
            }
        }
        return prefs.getInt(KEY_CURRENT_WEEK, 1).coerceAtLeast(1)
    }

    private fun formatSectionLabel(course: ParsedCourse): String {
        if (course.startSection > 0 && course.endSection >= course.startSection) {
            return if (course.startSection == course.endSection) {
                "第 ${course.startSection} 节"
            } else {
                "第 ${course.startSection}-${course.endSection} 节"
            }
        }
        val cal = Calendar.getInstance().apply { timeInMillis = course.startTime }
        val startMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val durMin = ((course.endTime - course.startTime) / 60000L).toInt()
        val span = when {
            durMin <= 60 -> 1
            durMin <= 115 -> 2
            durMin <= 165 -> 3
            else -> 4
        }
        val startSec = when {
            startMin < 9 * 60 + 15 -> 1
            startMin < 10 * 60 -> 2
            startMin < 11 * 60 + 30 -> 3
            startMin < 12 * 60 + 30 -> 4
            startMin < 14 * 60 + 30 -> 5
            startMin < 15 * 60 + 30 -> 6
            startMin < 16 * 60 + 30 -> 7
            startMin < 18 * 60 -> 8
            startMin < 19 * 60 + 30 -> 9
            else -> 11
        }
        val endSec = startSec + span - 1
        return if (startSec == endSec) "第 $startSec 节" else "第 $startSec-$endSec 节"
    }

    private fun cleanLocation(raw: String, fallback: String): String {
        val trimmed = raw.trim()
        return if (trimmed.isEmpty() || trimmed.contains("未知")) fallback else trimmed
    }

    private fun getHourOfDay(epochMs: Long): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        return cal.get(Calendar.HOUR_OF_DAY)
    }

    private fun formatRelativeDay(targetMs: Long, nowMs: Long): String {
        val nowCal = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val targetCal = Calendar.getInstance().apply {
            timeInMillis = targetMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val diffDays = ((targetCal.timeInMillis - nowCal.timeInMillis) / 86_400_000L).toInt()
        return when (diffDays) {
            0 -> "今天"
            1 -> "明天"
            2 -> "后天"
            else -> {
                val m = targetCal.get(Calendar.MONTH) + 1
                val d = targetCal.get(Calendar.DAY_OF_MONTH)
                "${m}月${d}日"
            }
        }
    }

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
            Log.d("CourseWidgets", "🛑 已取消 AlarmManager 课表精准唤醒闹钟")
        } catch (e: Exception) {
            Log.e("CourseWidgets", "取消精准闹钟失败: ${e.message}")
        }
    }
}
