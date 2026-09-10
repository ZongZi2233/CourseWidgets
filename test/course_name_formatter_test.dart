import 'package:flutter_test/flutter_test.dart';
import 'package:coursewidgets/ui/widgets/course_name_formatter.dart';

void main() {
  test('CourseNameFormatter semantic breaking and rules', () {
    // Rule 1: 本科毕业论文写作范式与技巧 -> 本科\n毕业论文\n写作范式\n与技巧
    final res1 = CourseNameFormatter.format('本科毕业论文写作范式与技巧');
    expect(res1, equals('本科\n毕业论文\n写作范式\n与技巧'));

    // Rule 2: BPT税务筹划 -> BPT\n税务筹划
    final res2 = CourseNameFormatter.format('BPT税务筹划');
    expect(res2, equals('BPT\n税务筹划'));

    // Rule 3: BS企业战略 -> stays intact
    final res3 = CourseNameFormatter.format('BS企业战略');
    expect(res3, equals('BS企业战略'));

    // Rule 4: Short course names stay intact
    final res4 = CourseNameFormatter.format('高等数学');
    expect(res4, equals('高等数学'));
  });
}
