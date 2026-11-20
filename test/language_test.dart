import 'dart:convert';

import 'package:casegen/ai.dart';
import 'package:casegen/cases.dart';
import 'package:casegen/language.dart';
import 'package:casegen/main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Language changes in settings, survives restart and applies to every case and prompt',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      addTearDown(() => appLanguage.value = 'es');
      await tester.pumpWidget(const CaseGen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Configuración'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('What is an uninterrupted hour worth?'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      appLanguage.value = 'es';
      await restoreLanguage();
      expect(appLanguage.value, 'en');
      final config = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'mock',
      );
      final cases = await BusinessCase.load();
      expect(cases, hasLength(8));
      for (final c in cases) {
        final en = c.localized('en');
        expect(en.title, isNot(c.title));
        expect(en.sources.values, orderedEquals(c.sources.values));
        final messages = config.payload(en, 'Mi propuesta')['messages'] as List;
        expect(messages.first['content'], contains('Reply in English'));
        final prompt = jsonDecode(messages.last['content']);
        expect(prompt['context'], en.brief);
        expect(prompt['proposal'], 'Mi propuesta');
      }
      await selectLanguage('es');
      final messages =
          config.payload(cases.first, 'My proposal')['messages'] as List;
      expect(messages.first['content'], contains('Responde en español'));
      expect(jsonDecode(messages.last['content'])['propuesta'], 'My proposal');
    },
  );
}
