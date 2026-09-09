import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ahmad_pharmacy_pos/data/repositories/medicine_repository.dart';
import 'package:ahmad_pharmacy_pos/data/models/medicine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MedicineRepository.getMedicines handles search query with SQL properly', () async {
    final repo = MedicineRepository();
    
    // Testing search query with string - should not throw SqfliteFfiException
    final results = await repo.getMedicines(query: 'pa');
    expect(results, isA<List<Medicine>>());
  });
}
