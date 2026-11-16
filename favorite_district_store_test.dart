import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkist/favorite_district_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorites stay isolated across signed-in accounts and guest', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_districts_preview': <String>['Eski ortak kayıt'],
    });
    await FavoriteDistrictStore.save('account-a', ['Adalar']);
    await FavoriteDistrictStore.save('account-b', ['Beşiktaş']);
    await FavoriteDistrictStore.save(null, ['Kadıköy']);

    expect(await FavoriteDistrictStore.load('account-a'), ['Adalar']);
    expect(await FavoriteDistrictStore.load('account-b'), ['Beşiktaş']);
    expect(await FavoriteDistrictStore.load(null), ['Kadıköy']);
    expect(await FavoriteDistrictStore.load('account-c'), isEmpty);
  });
}
