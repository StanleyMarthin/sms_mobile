import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_page.dart';

void main() {
  group('TotalProjectHoursFormatter', () {
    final formatter = TotalProjectHoursFormatter();

    TextEditingValue apply(String next) {
      return formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
      );
    }

    test('allows up to 3 digit hours and 2 digit minutes', () {
      expect(apply('12').text, '12');
      expect(apply('180').text, '180:');
      expect(apply('180:45').text, '180:45');
      expect(apply('180:4').text, '180:4');
    });

    test('rejects non-digit and out-of-range input', () {
      expect(apply('12a').text, '');
      expect(apply('1234').text, '');
      expect(apply('180:456').text, '');
    });
  });
}
