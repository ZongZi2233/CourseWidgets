import 'package:flutter_test/flutter_test.dart';
import 'package:coursewidgets/services/data_import_service.dart';

void main() {
  test('EAMS 53-week bitmask parsing correctly resolves 1-based weeks', () {
    // Week 1 and Week 2 active in 53-bit string
    const bitmask1 = '01100000000000000000000000000000000000000000000000000';
    final weeks1 = DataImportService.parseWeekString(bitmask1);
    expect(weeks1, equals([1, 2]));

    // Week 1, 3, 4, 8, 9
    const bitmask2 = '01011000110000000000000000000000000000000000000000000';
    final weeks2 = DataImportService.parseWeekString(bitmask2);
    expect(weeks2, equals([1, 3, 4, 8, 9]));

    // Human readable strings
    expect(DataImportService.parseWeekString('1-8周'), equals([1, 2, 3, 4, 5, 6, 7, 8]));
  });
}
