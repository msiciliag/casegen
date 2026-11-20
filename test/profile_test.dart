import 'package:casegen/profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'An optional profile can be created, reopened and edited locally',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await Profile.read(), isNull);
      await const Profile('Alex', true).save();
      expect((await Profile.read())!.name, 'Alex');
      expect((await Profile.read())!.fieldwork, isTrue);
      await const Profile('', false).save();
      expect((await Profile.read())!.name, '');
      expect((await Profile.read())!.fieldwork, isFalse);
    },
  );
}
