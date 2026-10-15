import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_ims/core/utils/csv.dart';

void main() {
  test('exported products CSV parses back into import rows', () {
    final csv = productsToCsv([
      {
        'name': 'Widget, large',
        'sku': 'W-1',
        'category': {'name': 'Tools'},
        'price': 12.5,
        'quantity': 3,
        'minimumStockLevel': 1,
        'status': 'In Stock',
        'supplier': 'ACME "Best"',
      },
    ]);
    final rows = parseProductsCsv(csv);
    expect(rows, hasLength(1));
    expect(rows.first['name'], 'Widget, large');
    expect(rows.first['category'], 'Tools');
    expect(rows.first['supplier'], 'ACME "Best"');
    expect(rows.first['minimumStockLevel'], '1');
  });

  test('import rejects a file without the required columns', () {
    expect(() => parseProductsCsv('Foo,Bar\n1,2'), throwsFormatException);
  });
}
