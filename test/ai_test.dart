import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:casegen/ai.dart';
import 'package:casegen/cases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Cambiar de destino requiere una clave nueva; olvidar elimina la conexión',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final previous = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'mock-old',
      );
      await previous.store();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openAiSettings(context),
              child: const Text('Ajustes'),
            ),
          ),
        ),
      );
      Future<void> edit() async {
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
      }

      await edit();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Groq'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro compatible con OpenAI').last);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(
        fields.at(0),
        'https://example.org/v1/chat/completions',
      );
      await tester.enterText(fields.at(1), 'prueba');
      await tester.tap(find.text('Guardar conexión'));
      await tester.pumpAndSettle();
      expect((await Connection.read())!.url, previous.url);
      expect(
        find.text('Introduce una clave válida para este destino.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(2), 'mock-new');
      await tester.tap(find.text('Guardar conexión'));
      await tester.pumpAndSettle();
      expect((await Connection.read())!.key, 'mock-new');
      await edit();
      await tester.tap(find.text('Olvidar clave y conexión'));
      await tester.pumpAndSettle();
      expect(await Connection.read(), isNull);
    },
  );
  test(
    'Groq usa los parámetros acordados y el proveedor alternativo recibe solo el contrato común',
    () async {
      final cases = await BusinessCase.load();
      expect(cases.where((c) => c.isFde).length, 5);
      final c = cases.firstWhere((c) => c.isFde);
      final config = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'mock',
      );
      final payload = config.payload(c, 'Mi propuesta');
      expect(payload['reasoning_effort'], 'medium');
      expect(payload['max_completion_tokens'], 2048);
      expect(payload['stream'], true);
      final other = Connection(
        checkedEndpoint('https://example.org/v1/chat/completions'),
        'modelo',
        'mock',
      );
      expect(
        other.payload(c, 'respuesta').containsKey('reasoning_effort'),
        false,
      );
      for (final endpoint in [
        'http://example.org/v1',
        'https://key@example.org/v1',
        'https://example.org/v1?key=x',
      ]) {
        expect(() => checkedEndpoint(endpoint), throwsFormatException);
      }
    },
  );
  test(
    'Streaming fragmentado: solo se muestra texto y un corte se detecta',
    () async {
      const events =
          'data: {"choices":[{"delta":{"reasoning":"interno"}}]}\r\n\r\ndata: {"choices":[{"delta":{"content":"útil"}}]}\n\ndata: [DONE]\n\n';
      final chunks = Stream.fromIterable(utf8.encode(events).map((b) => [b]));
      expect(await completionText(chunks).join(), 'útil');
      await expectLater(
        completionText(const Stream.empty()).toList(),
        throwsA(isA<ReviewError>()),
      );
    },
  );
}
