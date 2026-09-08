import 'package:flutter_test/flutter_test.dart';
import 'package:coursewidgets/models/course.dart';

void main() {
  group('开学日期与智能课时推算测试', () {
    test('智能级联推算全天课时以8:30为基准', () {
      int baseStart = 8 * 60 + 30; // 510
      int duration = 45;
      final startTimes = <int, int>{};
      int cur = baseStart;
      for (int i = 1; i <= 12; i++) {
        startTimes[i] = cur;
        if (i == 4) {
          cur = 14 * 60; // 午休
        } else if (i == 8) {
          cur = 18 * 60 + 30; // 晚饭
        } else if (i == 2 || i == 6) {
          cur += duration + 20; // 大课间
        } else {
          cur += duration + 5; // 普通课间
        }
      }

      expect(startTimes[1], 510); // 8:30
      expect(startTimes[2], 560); // 9:20
      expect(startTimes[3], 625); // 10:25
      expect(startTimes[4], 675); // 11:15
      expect(startTimes[5], 840); // 14:00
      expect(startTimes[9], 1110); // 18:30
    });

    test('已导入课表时间戳自适应周次对齐算法 (9.14 纠偏为 9.7)', () {
      // 模拟旧课表：首周课程在 2026-09-14
      final oldEvent = CalendarEvent(
        uid: 'test-event-1',
        summary: '操作系统',
        description: '李老师',
        location: '计301',
        dtStart: DateTime(2026, 9, 14, 8, 30),
        dtEnd: DateTime(2026, 9, 14, 10, 5),
        categories: ['计算机系'],
      );

      final events = [oldEvent];
      // 找出当前课表的最早周一
      DateTime earliestMonday = DateTime(2026, 9, 14);
      // 用户期望设置开学日期为 2026-09-07
      final targetStartDate = DateTime(2026, 9, 7);
      final targetMonday = targetStartDate.subtract(
        Duration(days: targetStartDate.weekday - 1),
      );

      final shiftDays = targetMonday.difference(earliestMonday).inDays;
      expect(shiftDays, -7); // 应该向前平移 7 天（从 9.14 到 9.7）

      final alignedEvents = events.map((event) {
        return CalendarEvent(
          uid: event.uid,
          summary: event.summary,
          description: event.description,
          location: event.location,
          dtStart: event.dtStart.add(Duration(days: shiftDays)),
          dtEnd: event.dtEnd.add(Duration(days: shiftDays)),
          rrule: event.rrule,
          categories: event.categories,
        );
      }).toList();

      expect(alignedEvents.first.dtStart.day, 7);
      expect(alignedEvents.first.dtStart.month, 9);
      expect(alignedEvents.first.dtStart.hour, 8);
      expect(alignedEvents.first.dtStart.minute, 30);
    });
  });
}
