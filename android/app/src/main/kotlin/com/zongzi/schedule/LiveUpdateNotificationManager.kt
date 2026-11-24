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
import kotlin.math.abs
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

    // 12 组与 Flutter CourseColorPalette.notificationPalette 对齐的高对比度课程主题色
    private val NOTIFICATION_PALETTE = intArrayOf(
        0xFFF43F5E.toInt(),
        0xFF10B981.toInt(),
        0xFF38BDF8.toInt(),
        0xFF8B5CF6.toInt(),
        0xFFF59E0B.toInt(),
        0xFFEC4899.toInt(),
        0xFF84CC16.toInt(),
        0xFF6366F1.toInt(),
        0xFF0EA5E9.toInt(),
        0xFFF97316.toInt(),
        0xFF14B8A6.toInt(),
        0xFFFB7185.toInt()
    )

    data class ClassroomInfo(
        val code: String,
        val venue: String,
        val raw: String
    ) {
        val isEmpty: Boolean get() = code.isEmpty() && venue.isEmpty()
        val hasVenue: Boolean get() = venue.isNotEmpty()
    }

    private data class ParsedCourse(
        val name: String,
        val location: String,
        val teacher: String,
        val startTime: Long,
        val endTime: Long,
        val startSection: Int,
        val endSection: Int,
        val colorArgb: Int = 0
    )

    data class TimelineSegment(
        val weight: Float,
        val isBreak: Boolean = false,
        val colorArgb: Int = 0
    )

    private data class LiveUpdateSnapshot(
        val headerSubText: String,
        val shortCapsuleText: String,
        val heroTitleSpan: CharSequence,
        val detailBodySpan: CharSequence,
        val bigDetailBodySpan: CharSequence,
        val badgePrimary: String,
        val badgeSecondary: String,
        val badgeBgColor: Int,
        val smallIconRes: Int,
        val accentColor: Int,
        val trackColor: Int,
        val isOngoingClass: Boolean,
        val showProgressBar: Boolean,
        val isBreakCountdownBar: Boolean,
        val targetWhenMs: Long?,
        val usesChronometer: Boolean,
        val isCountDown: Boolean,
        val segments: List<TimelineSegment>,
        val activeIndex: Int,
        val progressFraction: Float,
        val progressStyleMode: String
    )

    fun resolveCourseAccentColor(name: String, rawColorArgb: Int = 0): Int {
        if (rawColorArgb != 0) return rawColorArgb
        val idx = abs(name.hashCode()) % NOTIFICATION_PALETTE.size
        return NOTIFICATION_PALETTE[idx]
    }

    fun mixColor(fg: Int, bg: Int, ratio: Float): Int {
        val t = ratio.coerceIn(0f, 1f)
        val inv = 1f - t
        val a = ((android.graphics.Color.alpha(fg) * t) + (android.graphics.Color.alpha(bg) * inv)).toInt().coerceIn(0, 255)
        val r = ((android.graphics.Color.red(fg) * t) + (android.graphics.Color.red(bg) * inv)).toInt().coerceIn(0, 255)
        val g = ((android.graphics.Color.green(fg) * t) + (android.graphics.Color.green(bg) * inv)).toInt().coerceIn(0, 255)
        val b = ((android.graphics.Color.blue(fg) * t) + (android.graphics.Color.blue(bg) * inv)).toInt().coerceIn(0, 255)
        return android.graphics.Color.argb(a, r, g, b)
    }

    private fun darkenForBadge(argb: Int): Int = mixColor(argb, 0xFF0A0E16.toInt(), 0.78f)

    fun parseClassroomInfo(raw: String): ClassroomInfo {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed.contains("未知")) {
            return ClassroomInfo("", "", "")
        }

        val parenRegex = Regex("^(.+?)\\s*[（(]([^()（）]+)[)）]\\s*$")
        val parenMatch = parenRegex.find(trimmed)
        if (parenMatch != null) {
            val outer = parenMatch.groupValues[1].trim()
            val inner = parenMatch.groupValues[2].trim()
            val hasDigit = Regex("\\d")
            val outerDigits = hasDigit.containsMatchIn(outer)
            val innerDigits = hasDigit.containsMatchIn(inner)
            if (outerDigits && (!innerDigits || looksLikeRoomToken(outer))) {
                val outerParsed = parseLinearClassroom(outer, trimmed)
                val combinedVenue = listOfNotNull(
                    outerParsed.venue.takeIf { it.isNotEmpty() },
                    inner.takeIf { it.isNotEmpty() }
                ).joinToString(" · ")
                return ClassroomInfo(outerParsed.code, combinedVenue, trimmed)
            } else if (innerDigits) {
                val innerParsed = parseLinearClassroom(inner, trimmed)
                val combinedVenue = listOfNotNull(
                    outer.takeIf { it.isNotEmpty() },
                    innerParsed.venue.takeIf { it.isNotEmpty() }
                ).joinToString(" · ")
                return ClassroomInfo(innerParsed.code, combinedVenue, trimmed)
            }
        }
        return parseLinearClassroom(trimmed, trimmed)
    }

    private fun looksLikeRoomToken(token: String): Boolean {
        val cleaned = token.replaceFirst(Regex("室$"), "").trim()
        return Regex(
            "^([A-Za-z]{1,2}[-]?\\d{2,4}[A-Za-z]?|[东中西南北主甲乙丙丁][-]?\\d{2,4}[A-Za-z]?|教[一二三四五六七八九十\\d]+[-]?\\d{2,4}|\\d{3,4}[A-Za-z]?)$"
        ).matches(cleaned)
    }

    private fun parseLinearClassroom(input: String, rawOriginal: String): ClassroomInfo {
        val trimmed = input.trim()
        val leadingRegex = Regex(
            "^([A-Za-z]{1,2}[-]?\\d{2,4}[A-Za-z]?|[东中西南北主甲乙丙丁][-]?\\d{2,4}[A-Za-z]?|教[一二三四五六七八九十\\d]+[-]?\\d{2,4})室?[\\s·\\-_/]*(.*)$"
        )
        leadingRegex.find(trimmed)?.let { m ->
            val code = m.groupValues[1].trim().replaceFirst(Regex("室$"), "").trim()
            val rest = m.groupValues[2].trim().replaceFirst(Regex("^[\\s·\\-_/]+"), "").trim()
            return ClassroomInfo(code, rest, rawOriginal)
        }

        val trailingRegex = Regex(
            "^(.+?)[\\s·\\-_/]*([A-Za-z]{1,2}[-]?\\d{2,4}[A-Za-z]?|\\d{3,4}[A-Za-z]?)室?$"
        )
        trailingRegex.find(trimmed)?.let { m ->
            val building = m.groupValues[1].trim()
            val room = m.groupValues[2].trim().replaceFirst(Regex("室$"), "").trim()
            if (building.length == 1 && "东中西南北主甲乙丙丁".contains(building) && Regex("^\\d").containsMatchIn(room)) {
                return ClassroomInfo("$building$room", "", rawOriginal)
            }
            return ClassroomInfo(room, building, rawOriginal)
        }

        val stripped = if (Regex("\\d").containsMatchIn(trimmed)) {
            trimmed.replaceFirst(Regex("室$"), "").trim()
        } else {
            trimmed
        }
        return ClassroomInfo(stripped, "", rawOriginal)
    }

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
        builder.setCategory(
            if (snapshot.showProgressBar) Notification.CATEGORY_PROGRESS else Notification.CATEGORY_EVENT
        )
        builder.setVisibility(Notification.VISIBILITY_PUBLIC)
        @Suppress("DEPRECATION")
        builder.setPriority(Notification.PRIORITY_MAX)

        // 右侧高 DPI 真圆角独立徽章大图（官方 Android 16 Promoted Ongoing 完整支持，与设置页预览 1:1 对齐）
        val badgeBmp = createRoundedStatusBadgeBitmap(
            context = context,
            primaryText = snapshot.badgePrimary,
            secondaryText = snapshot.badgeSecondary,
            bgColor = snapshot.badgeBgColor
        )
        if (badgeBmp != null) {
            builder.setLargeIcon(badgeBmp)
        }

        // 状态栏胶囊短文本（Android 16 Promoted Ongoing 胶囊核心文字）
        val capsuleText = snapshot.shortCapsuleText.ifEmpty { subLocation ?: "进行中" }
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

        // 仅在需要展示实时进度（正在上课 / 45分钟内候课）时启用 ProgressStyle；
        // 当日无课、已结课或距首课尚早时彻底隐藏进度条，改用多行 BigTextStyle 保持完整展开高度
        if (snapshot.showProgressBar) {
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
                        .bigText(snapshot.bigDetailBodySpan)
                        .setSummaryText(snapshot.headerSubText)
                )
            }
        } else {
            builder.setProgress(0, 0, false)
            builder.setStyle(
                Notification.BigTextStyle()
                    .setBigContentTitle(titleSpan)
                    .bigText(snapshot.bigDetailBodySpan)
                    .setSummaryText(snapshot.headerSubText)
            )
        }

        // Android 16 Live Update (Promoted Ongoing) 提权标志
        val extras = android.os.Bundle()
        extras.putBoolean("android.requestPromotedOngoing", true)
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
     * - 直观清晰的粗胶囊进度条：正在上课按双模式（居中展开 / 按时长分段）渲染当日课程；
     *   课间 45 分钟内候课展示简洁单条准备倒计时（避免误以为下节课已进行一半）；
     * - 消除当前激活段末尾和总轨道末尾的冗余节点圆点，减少视觉干扰。
     */
    private fun buildNativeAndroid16ProgressStyle(
        context: Context,
        snapshot: LiveUpdateSnapshot
    ): Notification.ProgressStyle {
        val style = Notification.ProgressStyle()
        val totalCount = snapshot.segments.size.coerceAtLeast(1)
        val safeActive = snapshot.activeIndex.coerceIn(0, totalCount - 1)
        val clampedProgress = snapshot.progressFraction.coerceIn(0.03f, 0.98f)

        var cumulativePos = 0
        var trackerProgressPos = 0

        if (snapshot.isBreakCountdownBar || totalCount <= 1) {
            val totalLen = 200
            val segColor = if (snapshot.segments.isNotEmpty() && snapshot.segments[0].colorArgb != 0) {
                snapshot.segments[0].colorArgb
            } else {
                snapshot.accentColor
            }
            val segTrack = mixColor(segColor, 0xFF161A22.toInt(), 0.28f)
            val filledLen = (totalLen * clampedProgress).toInt().coerceIn(10, totalLen - 10)
            val remainLen = (totalLen - filledLen).coerceAtLeast(10)
            style.addProgressSegment(
                Notification.ProgressStyle.Segment(filledLen)
                    .setColor(segColor)
                    .setId(1)
            )
            style.addProgressSegment(
                Notification.ProgressStyle.Segment(remainLen)
                    .setColor(segTrack)
                    .setId(2)
            )
            trackerProgressPos = filledLen
        } else if (snapshot.progressStyleMode == STYLE_CENTERED_DOTS) {
            val sideSegLen = 16
            val centerPillLen = 180
            var segmentId = 1

            for (i in 0 until totalCount) {
                val baseColor = if (snapshot.segments[i].colorArgb != 0) {
                    snapshot.segments[i].colorArgb
                } else {
                    snapshot.accentColor
                }
                val pastColor = mixColor(baseColor, 0xFF3E4452.toInt(), 0.50f)
                val futureColor = mixColor(baseColor, 0xFF232833.toInt(), 0.65f)
                val segTrack = mixColor(baseColor, 0xFF161A22.toInt(), 0.28f)

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
                        val filledLen = (centerPillLen * clampedProgress).toInt().coerceIn(14, centerPillLen - 14)
                        val remainLen = (centerPillLen - filledLen).coerceAtLeast(14)
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(filledLen)
                                .setColor(baseColor)
                                .setId(segmentId++)
                        )
                        trackerProgressPos = cumulativePos + filledLen
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(remainLen)
                                .setColor(segTrack)
                                .setId(segmentId++)
                        )
                        cumulativePos += centerPillLen
                    }
                    else -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(sideSegLen)
                                .setColor(futureColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += sideSegLen
                        if (i < totalCount - 1) {
                            style.addProgressPoint(
                                Notification.ProgressStyle.Point(cumulativePos)
                                    .setColor(futureColor)
                                    .setId(i + 1)
                            )
                        }
                    }
                }
            }
        } else {
            var segmentId = 1
            for (i in 0 until totalCount) {
                val segLen = snapshot.segments[i].weight.toInt().coerceIn(40, 120)
                val baseColor = if (snapshot.segments[i].colorArgb != 0) {
                    snapshot.segments[i].colorArgb
                } else {
                    snapshot.accentColor
                }
                val pastColor = mixColor(baseColor, 0xFF3E4452.toInt(), 0.50f)
                val futureColor = mixColor(baseColor, 0xFF232833.toInt(), 0.65f)
                val segTrack = mixColor(baseColor, 0xFF161A22.toInt(), 0.28f)

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
                        val filledLen = (segLen * clampedProgress).toInt().coerceIn(12, segLen - 12)
                        val remainLen = (segLen - filledLen).coerceAtLeast(12)
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(filledLen)
                                .setColor(baseColor)
                                .setId(segmentId++)
                        )
                        trackerProgressPos = cumulativePos + filledLen
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(remainLen)
                                .setColor(segTrack)
                                .setId(segmentId++)
                        )
                        cumulativePos += segLen
                        if (i < totalCount - 1) {
                            val nextBase = if (snapshot.segments[i + 1].colorArgb != 0) {
                                snapshot.segments[i + 1].colorArgb
                            } else {
                                snapshot.accentColor
                            }
                            style.addProgressPoint(
                                Notification.ProgressStyle.Point(cumulativePos)
                                    .setColor(mixColor(nextBase, 0xFF232833.toInt(), 0.65f))
                                    .setId(i + 1)
                            )
                        }
                    }
                    else -> {
                        style.addProgressSegment(
                            Notification.ProgressStyle.Segment(segLen)
                                .setColor(futureColor)
                                .setId(segmentId++)
                        )
                        cumulativePos += segLen
                        if (i < totalCount - 1) {
                            style.addProgressPoint(
                                Notification.ProgressStyle.Point(cumulativePos)
                                    .setColor(futureColor)
                                    .setId(i + 1)
                            )
                        }
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
     * 渲染右侧 52dp×52dp 高 DPI 超椭圆风格真圆角徽章 Bitmap（优先显示核心教室编号如中1203，下附节次/日历标签）
     */
    private fun createRoundedStatusBadgeBitmap(
        context: Context,
        primaryText: String,
        secondaryText: String,
        bgColor: Int
    ): Bitmap? {
        return try {
            val density = context.resources.displayMetrics.density.coerceIn(2.5f, 4.0f)
            val sizePx = (52f * density).toInt()
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val cornerRadius = 15f * density

            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = bgColor
            }
            val bgRect = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
            canvas.drawRoundRect(bgRect, cornerRadius, cornerRadius, bgPaint)

            val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 1.2f * density
                color = 0x33FFFFFF
            }
            val borderInset = 0.6f * density
            canvas.drawRoundRect(
                RectF(borderInset, borderInset, sizePx - borderInset, sizePx - borderInset),
                cornerRadius - borderInset,
                cornerRadius - borderInset,
                borderPaint
            )

            val maxTextW = sizePx * 0.84f
            var primarySize = when {
                primaryText.length <= 2 -> 18.0f * density
                primaryText.length <= 4 -> 14.5f * density
                else -> 12.2f * density
            }
            val primaryPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textSize = primarySize
            }
            while (primaryPaint.measureText(primaryText) > maxTextW && primarySize > 9.0f * density) {
                primarySize -= 0.7f * density
                primaryPaint.textSize = primarySize
            }

            val cx = sizePx / 2f
            if (secondaryText.isNotEmpty()) {
                val pFm = primaryPaint.fontMetrics
                val pY = sizePx * 0.42f - (pFm.ascent + pFm.descent) / 2f
                canvas.drawText(primaryText, cx, pY, primaryPaint)

                val secPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = 0xE6FFFFFF.toInt()
                    textAlign = Paint.Align.CENTER
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    textSize = 9.4f * density
                }
                var secSize = 9.4f * density
                while (secPaint.measureText(secondaryText) > maxTextW && secSize > 7.5f * density) {
                    secSize -= 0.5f * density
                    secPaint.textSize = secSize
                }
                val sFm = secPaint.fontMetrics
                val sY = sizePx * 0.76f - (sFm.ascent + sFm.descent) / 2f
                canvas.drawText(secondaryText, cx, sY, secPaint)
            } else {
                val pFm = primaryPaint.fontMetrics
                val pY = sizePx * 0.50f - (pFm.ascent + pFm.descent) / 2f
                canvas.drawText(primaryText, cx, pY, primaryPaint)
            }

            bmp
        } catch (e: Exception) {
            Log.e("CourseWidgets", "创建真圆角状态徽章失败: ${e.message}")
            null
        }
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
                // ==================== 状态 A：正在上课（独立课程标题行 + 课程主题色胶囊教室标 + 分段染色进度） ====================
                val current = todayCourses[activeIdx]
                val nextCourse = if (activeIdx + 1 < todayCourses.size) todayCourses[activeIdx + 1] else null

                val accentColor = resolveCourseAccentColor(current.name, current.colorArgb)
                val badgeBgColor = darkenForBadge(accentColor)
                val trackColor = mixColor(accentColor, 0xFF161A22.toInt(), 0.28f)

                val secNums = formatSectionNumbersOnly(current)
                val startStr = timeFmt.format(Date(current.startTime))
                val endStr = timeFmt.format(Date(current.endTime))
                val classroom = parseClassroomInfo(current.location)

                val totalMs = max(1L, current.endTime - current.startTime)
                val progressFraction = ((now - current.startTime).toFloat() / totalMs.toFloat()).coerceIn(0.03f, 1f)
                val remainingMin = max(1, ((current.endTime - now + 59_999L) / 60_000L).toInt())

                // 课程名称独立成行且不染主题色，防止超长教室挤压课程信息
                val heroTitleSpan = SpannableStringBuilder()
                    .appendStyled(current.name, relativeSize = 1.14f, color = null, bold = true)

                val detailBodySpan = SpannableStringBuilder().apply {
                    if (!classroom.isEmpty) {
                        if (classroom.code.isNotEmpty()) {
                            appendStyled(classroom.code, relativeSize = 1.04f, color = accentColor, bold = true)
                        }
                        if (classroom.hasVenue) {
                            appendStyled(
                                if (classroom.code.isNotEmpty()) " ${classroom.venue}" else classroom.venue,
                                relativeSize = 0.90f,
                                color = 0xFFCBD5E1.toInt()
                            )
                        }
                        appendStyled(" · ", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                    }
                    appendStyled(endStr, relativeSize = 1.02f, color = accentColor, bold = true)
                    appendStyled(" 下课", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                    if (nextCourse != null) {
                        val nextAccent = resolveCourseAccentColor(nextCourse.name, nextCourse.colorArgb)
                        val nextStartStr = timeFmt.format(Date(nextCourse.startTime))
                        val nextRoom = parseClassroomInfo(nextCourse.location)
                        appendStyled(" · 下节 ", relativeSize = 0.84f, color = 0xFF8E95A3.toInt())
                        if (!nextRoom.isEmpty && nextRoom.code.isNotEmpty()) {
                            appendStyled(nextRoom.code, relativeSize = 0.96f, color = nextAccent, bold = true)
                            appendStyled(" ${nextCourse.name}", relativeSize = 0.90f, color = null, bold = true)
                        } else {
                            appendStyled("$nextStartStr ${nextCourse.name}", relativeSize = 0.90f, color = null, bold = true)
                        }
                    } else {
                        appendStyled(" · 今日最后一节", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                    }
                }

                val bigDetailBodySpan = SpannableStringBuilder().apply {
                    if (!classroom.isEmpty) {
                        if (classroom.code.isNotEmpty()) {
                            appendStyled(classroom.code, relativeSize = 1.06f, color = accentColor, bold = true)
                        }
                        if (classroom.hasVenue) {
                            appendStyled(" ${classroom.venue}", relativeSize = 0.92f, color = 0xFFCBD5E1.toInt())
                        }
                        append("\n")
                    }
                    appendStyled(endStr, relativeSize = 1.02f, color = accentColor, bold = true)
                    appendStyled(" 下课 · 第${secNums}节 ($startStr–$endStr)", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                    if (nextCourse != null) {
                        val nextAccent = resolveCourseAccentColor(nextCourse.name, nextCourse.colorArgb)
                        val nextRoom = parseClassroomInfo(nextCourse.location)
                        append("\n下节 ")
                        if (nextRoom.code.isNotEmpty()) {
                            appendStyled(nextRoom.code, relativeSize = 0.96f, color = nextAccent, bold = true)
                            appendStyled(" ${nextCourse.name}", relativeSize = 0.92f, color = null, bold = true)
                        } else {
                            appendStyled(nextCourse.name, relativeSize = 0.92f, color = null, bold = true)
                        }
                    }
                }

                val segments = todayCourses.map { c ->
                    val durMin = ((c.endTime - c.startTime) / 60000f).coerceIn(25f, 120f)
                    TimelineSegment(
                        weight = durMin,
                        isBreak = false,
                        colorArgb = resolveCourseAccentColor(c.name, c.colorArgb)
                    )
                }

                val timeChip = if (remainingMin >= 60) {
                    "${remainingMin / 60}h${remainingMin % 60}m"
                } else {
                    "剩${remainingMin}分"
                }
                val capsule = if (classroom.code.isNotEmpty() && classroom.code.length <= 5) {
                    "${classroom.code}·$timeChip"
                } else {
                    timeChip
                }

                return LiveUpdateSnapshot(
                    headerSubText = "进行中 · $startStr–$endStr",
                    shortCapsuleText = capsule,
                    heroTitleSpan = heroTitleSpan,
                    detailBodySpan = detailBodySpan,
                    bigDetailBodySpan = bigDetailBodySpan,
                    badgePrimary = if (classroom.code.isNotEmpty()) classroom.code else secNums,
                    badgeSecondary = if (classroom.code.isNotEmpty()) "${secNums}节" else "节",
                    badgeBgColor = badgeBgColor,
                    smallIconRes = R.drawable.ic_live_monster,
                    accentColor = accentColor,
                    trackColor = trackColor,
                    isOngoingClass = true,
                    showProgressBar = true,
                    isBreakCountdownBar = false,
                    targetWhenMs = current.endTime,
                    usesChronometer = true,
                    isCountDown = true,
                    segments = segments,
                    activeIndex = activeIdx,
                    progressFraction = progressFraction,
                    progressStyleMode = progressStyleMode
                )
            } else if (nextIdx >= 0) {
                // ==================== 状态 B：课间候课 / 今日首节前 ====================
                val nextCourse = todayCourses[nextIdx]
                val prevCourse = if (nextIdx > 0) todayCourses[nextIdx - 1] else null

                val accentColor = resolveCourseAccentColor(nextCourse.name, nextCourse.colorArgb)
                val badgeBgColor = darkenForBadge(accentColor)
                val trackColor = mixColor(accentColor, 0xFF161A22.toInt(), 0.28f)

                val todayWeekday = formatWeekday(now)
                val secNums = formatSectionNumbersOnly(nextCourse)
                val breakStartMs = prevCourse?.endTime ?: max(todayStart, nextCourse.startTime - 45 * 60_000L)
                val nextStartStr = timeFmt.format(Date(nextCourse.startTime))
                val nextEndStr = timeFmt.format(Date(nextCourse.endTime))
                val classroom = parseClassroomInfo(nextCourse.location)

                val totalBreakMs = max(1L, nextCourse.startTime - breakStartMs)
                val progressFraction = if (prevCourse != null || now >= breakStartMs) {
                    ((now - breakStartMs).toFloat() / totalBreakMs.toFloat()).coerceIn(0.05f, 1f)
                } else {
                    0.05f
                }
                val diffMin = max(1, ((nextCourse.startTime - now + 59_999L) / 60_000L).toInt())
                val remainTodayCount = todayCourses.size - nextIdx
                val showBreakBar = diffMin <= 45

                val heroTitleSpan = SpannableStringBuilder()
                    .appendStyled(nextCourse.name, relativeSize = 1.14f, color = null, bold = true)

                val detailBodySpan = SpannableStringBuilder().apply {
                    if (!classroom.isEmpty) {
                        if (classroom.code.isNotEmpty()) {
                            appendStyled(classroom.code, relativeSize = 1.04f, color = accentColor, bold = true)
                        }
                        if (classroom.hasVenue) {
                            appendStyled(
                                if (classroom.code.isNotEmpty()) " ${classroom.venue}" else classroom.venue,
                                relativeSize = 0.90f,
                                color = 0xFFCBD5E1.toInt()
                            )
                        }
                        appendStyled(" · ", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                    }
                    appendStyled(nextStartStr, relativeSize = 1.02f, color = accentColor, bold = true)
                    appendStyled(" 开课", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                    if (diffMin <= 90) {
                        val hintLabel = if (diffMin <= 15) "提前入座" else "课间候课"
                        appendStyled(" · $hintLabel", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                        if (remainTodayCount > 1) {
                            appendStyled(" · 余${remainTodayCount}门", relativeSize = 0.84f, color = 0xFF7D8594.toInt())
                        }
                    } else {
                        val waitStr = if (diffMin >= 60) "${diffMin / 60}小时${diffMin % 60}分" else "${diffMin}分钟"
                        appendStyled(" · 距开课 $waitStr", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                    }
                }

                val waitText = if (diffMin >= 60) "${diffMin / 60}小时${diffMin % 60}分" else "${diffMin}分钟"
                val teacherText = nextCourse.teacher.trim()
                val bigDetailBodySpan = SpannableStringBuilder().apply {
                    if (!classroom.isEmpty) {
                        if (classroom.code.isNotEmpty()) {
                            appendStyled(classroom.code, relativeSize = 1.06f, color = accentColor, bold = true)
                        }
                        if (classroom.hasVenue) {
                            appendStyled(" ${classroom.venue}", relativeSize = 0.92f, color = 0xFFCBD5E1.toInt())
                        }
                    } else {
                        appendStyled("未指定教室", relativeSize = 0.92f, color = 0xFF8E95A3.toInt())
                    }
                    appendStyled(" · $nextStartStr–$nextEndStr\n", relativeSize = 0.90f, color = 0xFF9CA3AF.toInt())
                    appendStyled("距开课 $waitText", relativeSize = 0.94f, color = accentColor, bold = true)
                    appendStyled(
                        " · 第${secNums}节${if (teacherText.isNotEmpty()) " · $teacherText" else ""}\n",
                        relativeSize = 0.88f,
                        color = 0xFF9CA3AF.toInt()
                    )
                    appendStyled("今日共 ${todayCourses.size} 门课程 · 后续 ${remainTodayCount} 门待上", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
                }

                val shortCapsule = when {
                    diffMin <= 90 && classroom.code.isNotEmpty() && classroom.code.length <= 5 -> "${classroom.code}·${diffMin}分"
                    diffMin <= 90 -> "${diffMin}分后"
                    else -> "${todayWeekday}·$nextStartStr"
                }
                val headerLabel = when {
                    prevCourse == null -> "今日${todayWeekday} · $nextStartStr–$nextEndStr"
                    diffMin <= 15 -> "即将开课 · $nextStartStr–$nextEndStr"
                    else -> "课间候课 · $nextStartStr–$nextEndStr"
                }

                return LiveUpdateSnapshot(
                    headerSubText = headerLabel,
                    shortCapsuleText = shortCapsule,
                    heroTitleSpan = heroTitleSpan,
                    detailBodySpan = detailBodySpan,
                    bigDetailBodySpan = bigDetailBodySpan,
                    badgePrimary = if (classroom.code.isNotEmpty()) classroom.code else secNums,
                    badgeSecondary = if (classroom.code.isNotEmpty()) "${secNums}节" else "节",
                    badgeBgColor = badgeBgColor,
                    smallIconRes = R.drawable.ic_live_walker,
                    accentColor = accentColor,
                    trackColor = trackColor,
                    isOngoingClass = false,
                    showProgressBar = showBreakBar,
                    isBreakCountdownBar = true,
                    targetWhenMs = nextCourse.startTime,
                    usesChronometer = diffMin <= 90,
                    isCountDown = true,
                    segments = listOf(TimelineSegment(45f, colorArgb = accentColor)),
                    activeIndex = 0,
                    progressFraction = progressFraction,
                    progressStyleMode = progressStyleMode
                )
            }
        }

        // ==================== 状态 C：今日课程已结束或无课（隐藏进度条，使用多行 BigTextStyle 保持完整高度） ====================
        val futureCourse = allCourses.filter { it.startTime > now }.minByOrNull { it.startTime }

        if (futureCourse != null) {
            val accentColor = resolveCourseAccentColor(futureCourse.name, futureCourse.colorArgb)
            val badgeBgColor = darkenForBadge(accentColor)
            val trackColor = mixColor(accentColor, 0xFF161A22.toInt(), 0.28f)

            val startStr = timeFmt.format(Date(futureCourse.startTime))
            val endStr = timeFmt.format(Date(futureCourse.endTime))
            val relDay = formatRelativeDay(futureCourse.startTime, now)
            val shortRelBadge = formatShortRelDayBadge(futureCourse.startTime, now)
            val targetWeekday = formatWeekday(futureCourse.startTime)
            val classroom = parseClassroomInfo(futureCourse.location)
            val sectionLabel = formatSectionLabel(futureCourse)

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
            val targetCount = targetDayCourses.size.coerceAtLeast(1)

            val heroTitleSpan = SpannableStringBuilder()
                .appendStyled(futureCourse.name, relativeSize = 1.14f, color = null, bold = true)

            val todayPrefix = if (todayCourses.isNotEmpty()) "今日已结课" else "今日无课"
            val teacher = futureCourse.teacher.trim()

            val detailBodySpan = SpannableStringBuilder().apply {
                if (!classroom.isEmpty) {
                    if (classroom.code.isNotEmpty()) {
                        appendStyled(classroom.code, relativeSize = 1.04f, color = accentColor, bold = true)
                    }
                    if (classroom.hasVenue) {
                        appendStyled(" ${classroom.venue}", relativeSize = 0.90f, color = 0xFFCBD5E1.toInt())
                    }
                    appendStyled(" · ", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                }
                appendStyled("$relDay ", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                appendStyled("$startStr–$endStr", relativeSize = 0.98f, color = accentColor, bold = true)
                appendStyled(" · $sectionLabel", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
            }

            val bigDetailBodySpan = SpannableStringBuilder().apply {
                if (!classroom.isEmpty) {
                    if (classroom.code.isNotEmpty()) {
                        appendStyled(classroom.code, relativeSize = 1.06f, color = accentColor, bold = true)
                    }
                    if (classroom.hasVenue) {
                        appendStyled(" ${classroom.venue}", relativeSize = 0.92f, color = 0xFFCBD5E1.toInt())
                    }
                    appendStyled(" · ", relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
                }
                appendStyled("$relDay $startStr–$endStr\n", relativeSize = 0.96f, color = accentColor, bold = true)
                appendStyled(
                    "$todayPrefix · $sectionLabel${if (teacher.isNotEmpty()) " · $teacher" else ""}\n",
                    relativeSize = 0.88f,
                    color = 0xFF9CA3AF.toInt()
                )
                appendStyled("当日共 $targetCount 门课程 · $weekLabel", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())
            }

            return LiveUpdateSnapshot(
                headerSubText = "$relDay · 共${targetCount}门 · $weekLabel",
                shortCapsuleText = "$targetWeekday·$startStr",
                heroTitleSpan = heroTitleSpan,
                detailBodySpan = detailBodySpan,
                bigDetailBodySpan = bigDetailBodySpan,
                badgePrimary = if (classroom.code.isNotEmpty()) classroom.code else shortRelBadge,
                badgeSecondary = if (classroom.code.isNotEmpty()) "$shortRelBadge·${targetCount}门" else "${targetCount}门",
                badgeBgColor = badgeBgColor,
                smallIconRes = R.drawable.ic_live_walker,
                accentColor = accentColor,
                trackColor = trackColor,
                isOngoingClass = false,
                showProgressBar = false,
                isBreakCountdownBar = false,
                targetWhenMs = null,
                usesChronometer = false,
                isCountDown = false,
                segments = emptyList(),
                activeIndex = 0,
                progressFraction = 0.0f,
                progressStyleMode = progressStyleMode
            )
        }

        // ==================== 状态 D：近期暂无排课（彻底隐藏进度条并维持多行饱满卡片高度） ====================
        val fallbackTitleSpan = SpannableStringBuilder()
            .appendStyled(fallbackTitle.ifEmpty { "今日暂无课程安排" }, relativeSize = 1.14f, color = null, bold = true)
        val fallbackBodySpan = SpannableStringBuilder()
            .appendStyled(fallbackBody.ifEmpty { "今日无课 · $weekLabel · 点击查看周课表" }, relativeSize = 0.88f, color = 0xFF8E95A3.toInt())
        val fallbackBigBodySpan = SpannableStringBuilder()
            .appendStyled("今日无课 · $weekLabel\n", relativeSize = 0.94f, color = 0xFFCBD5E1.toInt(), bold = true)
            .appendStyled("当前日期与近期暂无待上课程\n", relativeSize = 0.88f, color = 0xFF9CA3AF.toInt())
            .appendStyled("点击通知卡片查看完整周课表", relativeSize = 0.86f, color = 0xFF8E95A3.toInt())

        return LiveUpdateSnapshot(
            headerSubText = "$weekLabel · 今日无课",
            shortCapsuleText = fallbackSubLocation ?: "今日无课",
            heroTitleSpan = fallbackTitleSpan,
            detailBodySpan = fallbackBodySpan,
            bigDetailBodySpan = fallbackBigBodySpan,
            badgePrimary = "无课",
            badgeSecondary = "第${weekNumber}周",
            badgeBgColor = 0xFF475569.toInt(),
            smallIconRes = R.drawable.ic_live_monster,
            accentColor = 0xFF10B981.toInt(),
            trackColor = 0xFF1F4235.toInt(),
            isOngoingClass = false,
            showProgressBar = false,
            isBreakCountdownBar = false,
            targetWhenMs = null,
            usesChronometer = false,
            isCountDown = false,
            segments = emptyList(),
            activeIndex = 0,
            progressFraction = 0.0f,
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
                val baseColor = if (segments[i].colorArgb != 0) segments[i].colorArgb else accentColor
                val pastDot = mixColor(baseColor, 0xFF3E4452.toInt(), 0.55f)
                val futureDot = mixColor(baseColor, 0xFF232833.toInt(), 0.65f)
                val segTrack = mixColor(baseColor, 0xFF161A22.toInt(), 0.28f)
                if (i < safeActive) {
                    paint.color = pastDot
                    val cx = cursorX + dotDiameter / 2f
                    canvas.drawCircle(cx, barH / 2f, dotDiameter / 2f, paint)
                    cursorX += dotDiameter + gap
                } else if (i == safeActive) {
                    val rect = RectF(cursorX, 0f, cursorX + pillWidth, barH)
                    paint.color = segTrack
                    canvas.drawRoundRect(rect, radius, radius, paint)
                    if (clampedProgress > 0.01f) {
                        val fillW = (pillWidth * clampedProgress).coerceIn(barH, pillWidth)
                        val fillRect = RectF(cursorX, 0f, cursorX + fillW, barH)
                        paint.color = baseColor
                        canvas.drawRoundRect(fillRect, radius, radius, paint)
                    }
                    cursorX += pillWidth + gap
                } else {
                    paint.color = futureDot
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
                val baseColor = if (segments[i].colorArgb != 0) segments[i].colorArgb else accentColor
                val pastSeg = mixColor(baseColor, 0xFF3E4452.toInt(), 0.55f)
                val futureSeg = mixColor(baseColor, 0xFF232833.toInt(), 0.65f)
                val segTrack = mixColor(baseColor, 0xFF161A22.toInt(), 0.28f)
                when {
                    i < safeActive -> {
                        paint.color = pastSeg
                        canvas.drawRoundRect(rect, radius, radius, paint)
                    }
                    i == safeActive -> {
                        paint.color = segTrack
                        canvas.drawRoundRect(rect, radius, radius, paint)
                        if (clampedProgress > 0.01f) {
                            val fillW = (w * clampedProgress).coerceIn(min(barH, w), w)
                            val fillRect = RectF(cursorX, 0f, cursorX + fillW, barH)
                            paint.color = baseColor
                            canvas.drawRoundRect(fillRect, radius, radius, paint)
                        }
                    }
                    else -> {
                        paint.color = futureSeg
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
                        endSection = endSec,
                        colorArgb = obj.optInt("colorArgb", 0)
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

    private fun formatSectionNumbersOnly(course: ParsedCourse): String {
        if (course.startSection > 0 && course.endSection >= course.startSection) {
            return if (course.startSection == course.endSection) {
                "${course.startSection}"
            } else {
                "${course.startSection}-${course.endSection}"
            }
        }
        return formatSectionLabel(course)
            .replace("第", "")
            .replace("节", "")
            .replace(" ", "")
    }

    private fun formatShortRelDayBadge(targetMs: Long, nowMs: Long): String {
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
            0 -> "今日"
            1 -> "明日"
            2 -> "后天"
            else -> formatWeekday(targetMs)
        }
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

    private fun formatWeekday(epochMs: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "周一"
            Calendar.TUESDAY -> "周二"
            Calendar.WEDNESDAY -> "周三"
            Calendar.THURSDAY -> "周四"
            Calendar.FRIDAY -> "周五"
            Calendar.SATURDAY -> "周六"
            Calendar.SUNDAY -> "周日"
            else -> ""
        }
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
        val weekday = formatWeekday(targetMs)
        val diffDays = ((targetCal.timeInMillis - nowCal.timeInMillis) / 86_400_000L).toInt()
        return when (diffDays) {
            0 -> "今日$weekday"
            1 -> "明日$weekday"
            2 -> "后天$weekday"
            else -> {
                val m = targetCal.get(Calendar.MONTH) + 1
                val d = targetCal.get(Calendar.DAY_OF_MONTH)
                "${m}月${d}日 $weekday"
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
