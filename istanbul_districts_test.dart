import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/istanbul_districts.dart';

void main() {
  test('Istanbul district filter has all 39 unique districts', () {
    final names = istanbulDistricts.map((district) => district.name).toList();

    expect(names, hasLength(39));
    expect(names.toSet(), hasLength(39));
    expect(names, containsAll(<String>['Kadıköy', 'Üsküdar', 'Şişli']));
  });
}
