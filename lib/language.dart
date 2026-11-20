import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final appLanguage = ValueNotifier<String>('es');
const _storage = FlutterSecureStorage();
const _key = 'casegen.language';

Future<void> restoreLanguage() async {
  final saved = await _storage.read(key: _key);
  appLanguage.value = saved == 'en' ? 'en' : 'es';
}

Future<void> selectLanguage(String code) async {
  await _storage.write(key: _key, value: code);
  appLanguage.value = code;
}

String tr(String spanish, String english) =>
    appLanguage.value == 'en' ? english : spanish;
