import 'dart:convert';
import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:casegen/cases.dart';
import 'package:casegen/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RetiredEditionHistory extends History {
  final BusinessCase retired;
  RetiredEditionHistory(this.retired);

  @override
  Future<List<Map<String, Object?>>> all() async => [];
  @override
  Future<Map<String, BusinessCase>> draftCases() async => {retired.id: retired};
  @override
  Future<Map<String, dynamic>?> draft(String id) async => {
    'snapshot': retired.data,
    'deciding': true,
    'move': 0,
    'answer': 'Mi razonamiento anterior',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RetiredEditionHistory history;
  setUpAll(() async {
    final original = BusinessCase(
      'netflix',
      jsonDecode(File('cases/netflix.json').readAsStringSync()),
    );
    history = RetiredEditionHistory(
      BusinessCase('news-retired', {
        ...original.data,
        'title': 'Edición retirada de la portada',
      }),
    );
  });
  testWidgets(
    'Profile can reopen an unfinished case after it leaves the feed',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          locale: const Locale('es'),
          home: Library(history: history),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      final saved = find.text('Edición retirada de la portada');
      await tester.ensureVisible(saved);
      await tester.tap(saved);
      await tester.pumpAndSettle();
      expect(find.text('Edición retirada de la portada'), findsOneWidget);
      final field = find.byType(TextField);
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Mi razonamiento anterior',
      );
    },
  );
}
