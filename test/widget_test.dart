import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/utils/format.dart';

void main() {
  test('formatMoney aplica formato de moneda', () {
    expect(formatMoney(1234.5), r'$1,234.50');
    expect(formatMoney(0), r'$0.00');
    expect(formatMoney(-50), r'-$50.00');
  });
}
